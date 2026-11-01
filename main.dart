import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// ===================================================
// 金爵國際 出勤管理
// 小姐：上班打卡、外出、回店、下班打卡、看自己的紀錄
// 管理員：看今日人數、統計、管理名單
// 目前資料存在手機記憶體裡（重新整理會回到測試資料），
// 下一步接 Firebase 後，大家的手機就會同步。
// ===================================================

void main() {
  runApp(const MyApp());
}

const String appName = '金爵國際';
const Color gold = Color(0xFFC9A227);
const Color pageBg = Color(0xFFF5F5F5);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appName,
      theme: ThemeData(colorSchemeSeed: gold),
      home: const LoginPage(),
    );
  }
}

// ===================================================
// 小工具
// ===================================================
String two(int n) => n.toString().padLeft(2, '0');
String fmtTime(DateTime t) => '${two(t.hour)}:${two(t.minute)}';
const List<String> weekdays = ['一', '二', '三', '四', '五', '六', '日'];
String fmtDate(DateTime d) => '${d.month}/${d.day}（${weekdays[d.weekday - 1]}）';
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// 營業日：早上 8 點才換日，所以晚上上班、凌晨下班都算同一天
DateTime businessDay(DateTime t) =>
    dateOnly(t.subtract(const Duration(hours: 8)));

bool inRange(DateTime day, DateTime start, DateTime end) =>
    !day.isBefore(start) && day.isBefore(end);

AppBar blackBar(String title, {List<Widget>? actions}) {
  return AppBar(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
    centerTitle: true,
    title: Text(title),
    actions: actions,
  );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
}

Future<bool> confirmDialog(
    BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('確定'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Widget logoutButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.logout),
    tooltip: '登出',
    onPressed: () async {
      final ok = await confirmDialog(context, '登出', '確定要登出嗎？');
      if (ok && context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    },
  );
}

Widget bigButton(
    String label, IconData icon, Color color, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

// 白底數字小方塊（例如「今日上班 5 人」）
Widget statBox(String label, String value, {Color color = Colors.black}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );
}

// ===================================================
// 資料
// ===================================================
class Hostess {
  final String id;
  String name;
  String phone;
  String password;
  bool approved; // 自己註冊的帳號要管理員核准才能登入
  bool locationConsent = false; // 是否已同意打卡時記錄位置
  Hostess({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    this.approved = true,
  });
}

// 一個定位點
class LocationPoint {
  final double lat;
  final double lng;
  final double accuracy; // 誤差（公尺）
  LocationPoint({required this.lat, required this.lng, required this.accuracy});
}

// 一次上班（打卡上班 ～ 打卡下班）
class Attendance {
  final String hostessId;
  final DateTime clockIn;
  DateTime? clockOut;
  LocationPoint? inLoc; // 上班打卡位置
  LocationPoint? outLoc; // 下班打卡位置
  Attendance({
    required this.hostessId,
    required this.clockIn,
    this.clockOut,
    this.inLoc,
    this.outLoc,
  });
}

// 一次外出（出發 ～ 回店）
class Dispatch {
  final String hostessId;
  final String place;
  final DateTime outTime;
  DateTime? backTime;
  LocationPoint? outLoc; // 出發時位置
  LocationPoint? backLoc; // 回店時位置
  Dispatch({
    required this.hostessId,
    required this.place,
    required this.outTime,
    this.backTime,
    this.outLoc,
    this.backLoc,
  });
}

enum WorkStatus { notIn, inStore, out, off }

extension WorkStatusText on WorkStatus {
  String get label {
    switch (this) {
      case WorkStatus.notIn:
        return '未到';
      case WorkStatus.inStore:
        return '在店';
      case WorkStatus.out:
        return '外出中';
      case WorkStatus.off:
        return '已下班';
    }
  }

  Color get color {
    switch (this) {
      case WorkStatus.notIn:
        return Colors.grey;
      case WorkStatus.inStore:
        return Colors.green;
      case WorkStatus.out:
        return Colors.orange;
      case WorkStatus.off:
        return Colors.blueGrey;
    }
  }

  // 管理員列表排序：外出中 → 在店 → 已下班 → 未到
  int get sortRank {
    switch (this) {
      case WorkStatus.out:
        return 0;
      case WorkStatus.inStore:
        return 1;
      case WorkStatus.off:
        return 2;
      case WorkStatus.notIn:
        return 3;
    }
  }
}

class TimelineEvent {
  final DateTime time;
  final String label;
  final IconData icon;
  final Color color;
  final LocationPoint? loc;
  TimelineEvent(this.time, this.label, this.icon, this.color, this.loc);
}

// ===================================================
// 資料中心：所有資料和動作都在這裡
// 之後接 Firebase，主要就是改這一塊
// ===================================================
class AppStore extends ChangeNotifier {
  final List<Hostess> hostesses = [];
  final List<Attendance> attendances = [];
  final List<Dispatch> dispatches = [];
  final List<String> commonPlaces = ['金星會館', '皇家飯店', '水晶酒店', '銀河KTV'];
  int _nextId = 1;

  // ---------- 店家位置設定（管理員設定） ----------
  double? storeLat;
  double? storeLng;
  double radius = 100; // 允許範圍（公尺）
  bool requireInRange = true; // 上班打卡是否必須在範圍內

  bool get hasStoreLocation => storeLat != null && storeLng != null;

  // 離店家幾公尺（沒設定店家位置就回傳 null）
  double? distanceToStore(LocationPoint p) {
    if (!hasStoreLocation) return null;
    return Geolocator.distanceBetween(storeLat!, storeLng!, p.lat, p.lng);
  }

  void setStoreSettings(
      double? lat, double? lng, double newRadius, bool require) {
    storeLat = lat;
    storeLng = lng;
    radius = newRadius;
    requireInRange = require;
    notifyListeners();
  }

  void giveLocationConsent(Hostess h) {
    h.locationConsent = true;
    notifyListeners();
  }

  AppStore() {
    _seed();
  }

  String _newId() => 'h${_nextId++}';

  Hostess? findByPhone(String phone) {
    for (final h in hostesses) {
      if (h.phone == phone) return h;
    }
    return null;
  }

  // 今天（營業日）的上班紀錄
  Attendance? todayAttendance(String hostessId) {
    final today = businessDay(DateTime.now());
    Attendance? result;
    for (final a in attendances) {
      if (a.hostessId == hostessId && businessDay(a.clockIn) == today) {
        result = a;
      }
    }
    return result;
  }

  // 目前還沒回店的外出
  Dispatch? currentDispatch(String hostessId) {
    for (final d in dispatches) {
      if (d.hostessId == hostessId && d.backTime == null) return d;
    }
    return null;
  }

  WorkStatus statusOf(String hostessId) {
    final att = todayAttendance(hostessId);
    if (att == null) return WorkStatus.notIn;
    if (att.clockOut != null) return WorkStatus.off;
    if (currentDispatch(hostessId) != null) return WorkStatus.out;
    return WorkStatus.inStore;
  }

  List<Dispatch> dispatchesOnDay(String hostessId, DateTime day) {
    return dispatches
        .where((d) => d.hostessId == hostessId && businessDay(d.outTime) == day)
        .toList();
  }

  List<TimelineEvent> eventsOnDay(String hostessId, DateTime day) {
    final events = <TimelineEvent>[];
    for (final a in attendances) {
      if (a.hostessId == hostessId && businessDay(a.clockIn) == day) {
        events.add(TimelineEvent(
            a.clockIn, '上班打卡', Icons.login, Colors.green, a.inLoc));
        if (a.clockOut != null) {
          events.add(TimelineEvent(
              a.clockOut!, '下班打卡', Icons.logout, Colors.red, a.outLoc));
        }
      }
    }
    for (final d in dispatchesOnDay(hostessId, day)) {
      events.add(TimelineEvent(d.outTime, '外出：${d.place}',
          Icons.directions_car, Colors.orange, d.outLoc));
      if (d.backTime != null) {
        events.add(TimelineEvent(
            d.backTime!, '回店', Icons.storefront, Colors.blue, d.backLoc));
      }
    }
    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  String nameOf(String hostessId) {
    for (final h in hostesses) {
      if (h.id == hostessId) return h.name;
    }
    return '（已刪除）';
  }

  // ---------- 打卡動作 ----------
  void clockIn(String hostessId, {LocationPoint? loc}) {
    if (todayAttendance(hostessId) != null) return;
    attendances.add(Attendance(
        hostessId: hostessId, clockIn: DateTime.now(), inLoc: loc));
    notifyListeners();
  }

  void goOut(String hostessId, String place, {LocationPoint? loc}) {
    if (currentDispatch(hostessId) != null) return;
    dispatches.add(Dispatch(
        hostessId: hostessId,
        place: place,
        outTime: DateTime.now(),
        outLoc: loc));
    if (!commonPlaces.contains(place)) commonPlaces.add(place);
    notifyListeners();
  }

  void comeBack(String hostessId, {LocationPoint? loc}) {
    final d = currentDispatch(hostessId);
    if (d == null) return;
    d.backTime = DateTime.now();
    d.backLoc = loc;
    notifyListeners();
  }

  void clockOut(String hostessId, {LocationPoint? loc}) {
    final d = currentDispatch(hostessId);
    if (d != null) {
      d.backTime = DateTime.now(); // 外出中直接下班，順便算回店
      d.backLoc = loc;
    }
    final att = todayAttendance(hostessId);
    if (att == null || att.clockOut != null) return;
    att.clockOut = DateTime.now();
    att.outLoc = loc;
    notifyListeners();
  }

  // ---------- 名單管理 ----------
  // 已核准的人（今日、統計只算這些人）
  List<Hostess> get approvedHostesses =>
      hostesses.where((h) => h.approved).toList();

  // 等待核准的新註冊
  List<Hostess> get pendingHostesses =>
      hostesses.where((h) => !h.approved).toList();

  // 管理員新增：直接核准
  void addHostess(String name, String phone, String password) {
    hostesses.add(Hostess(
        id: _newId(), name: name, phone: phone, password: password));
    notifyListeners();
  }

  // 小姐自己註冊：等管理員核准
  void registerHostess(String name, String phone, String password) {
    hostesses.add(Hostess(
      id: _newId(),
      name: name,
      phone: phone,
      password: password,
      approved: false,
    ));
    notifyListeners();
  }

  void approveHostess(Hostess h) {
    h.approved = true;
    notifyListeners();
  }

  void updateHostess(Hostess h, String name, String phone, String password) {
    h.name = name;
    h.phone = phone;
    if (password.isNotEmpty) h.password = password; // 空白 = 不改密碼
    notifyListeners();
  }

  void removeHostess(Hostess h) {
    hostesses.remove(h);
    notifyListeners();
  }

  // ---------- 測試資料 ----------
  void _seed() {
    const names = ['小美', '小雪', '小琪', '小婷', '小安', '小玲'];
    for (var i = 0; i < names.length; i++) {
      hostesses.add(Hostess(
        id: _newId(),
        name: names[i],
        phone: '09110000${two(i + 1)}',
        password: '123456',
      ));
    }
    // 一位剛註冊、等待核准的（測試用）
    hostesses.add(Hostess(
      id: _newId(),
      name: '小芳',
      phone: '0911000007',
      password: '123456',
      approved: false,
    ));
    final working = approvedHostesses; // 下面的測試紀錄只給已核准的人

    final today = businessDay(DateTime.now());

    // 過去 40 天的紀錄
    for (var d = 1; d <= 40; d++) {
      final day = DateTime(today.year, today.month, today.day - d);
      for (var i = 0; i < working.length; i++) {
        if ((d + i) % 3 == 0) continue; // 有幾天休假
        final h = working[i];
        final inTime = day.add(Duration(hours: 20, minutes: i * 7));
        final outTime = day.add(Duration(hours: 27, minutes: i * 5));
        attendances.add(
            Attendance(hostessId: h.id, clockIn: inTime, clockOut: outTime));
        final times = (d + i) % 4;
        for (var k = 0; k < times; k++) {
          final o = inTime.add(Duration(hours: 1 + k * 2));
          dispatches.add(Dispatch(
            hostessId: h.id,
            place: commonPlaces[(d + i + k) % commonPlaces.length],
            outTime: o,
            backTime: o.add(const Duration(minutes: 70)),
          ));
        }
      }
    }

    // 今天：放幾筆讓畫面有東西看
    final now = DateTime.now();
    final dayStart = today.add(const Duration(hours: 8));
    if (now.subtract(const Duration(hours: 3)).isAfter(dayStart)) {
      final h0 = hostesses[0].id;
      final h1 = hostesses[1].id;
      final h2 = hostesses[2].id;
      attendances.add(Attendance(
          hostessId: h0, clockIn: now.subtract(const Duration(hours: 2))));
      dispatches.add(Dispatch(
        hostessId: h0,
        place: commonPlaces[0],
        outTime: now.subtract(const Duration(minutes: 90)),
        backTime: now.subtract(const Duration(minutes: 30)),
      ));
      attendances.add(Attendance(
          hostessId: h1, clockIn: now.subtract(const Duration(hours: 3))));
      dispatches.add(Dispatch(
        hostessId: h1,
        place: commonPlaces[1],
        outTime: now.subtract(const Duration(minutes: 40)),
      ));
      attendances.add(Attendance(
          hostessId: h2, clockIn: now.subtract(const Duration(hours: 1))));
    }
  }
}

final store = AppStore();

// ===================================================
// 定位
// ===================================================

// 取得目前位置（會顯示「定位中」），失敗回傳 null
Future<LocationPoint?> getCurrentLocation(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('定位中，請稍候…')),
        ],
      ),
    ),
  );

  LocationPoint? result;
  String? error;
  try {
    // 網頁版：直接取位置，瀏覽器會自己跳出詢問
    if (!kIsWeb) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        error = '沒有定位權限，請到手機設定允許使用位置';
      }
    }
    if (error == null) {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      result = LocationPoint(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );
    }
  } catch (e) {
    error = '定位失敗：請確認手機定位已開啟，並允許 Safari 使用位置';
  }

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop(); // 關掉「定位中」
    if (error != null) toast(context, error);
  }
  return result;
}

// 在 Google 地圖打開位置
Future<void> openMap(double lat, double lng) async {
  final uri =
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// 位置的文字說明，例如「距離店家 35 公尺」
String locationText(LocationPoint? loc) {
  if (loc == null) return '沒有定位';
  final d = store.distanceToStore(loc);
  var text = d == null ? '已記錄位置' : '距離店家 ${d.round()} 公尺';
  if (loc.accuracy > 100) text += '（訊號弱，誤差約 ${loc.accuracy.round()} 公尺）';
  return text;
}

bool isOutOfRange(LocationPoint? loc) {
  if (loc == null) return false;
  final d = store.distanceToStore(loc);
  return d != null && d > store.radius;
}

// 第一次打卡前，請小姐同意記錄位置
Future<bool> ensureLocationConsent(BuildContext context, Hostess h) async {
  if (h.locationConsent) return true;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('打卡定位說明'),
      content: const Text(
        '按打卡按鈕（上班、外出、回店、下班）時，會記錄你當下的位置。\n\n'
        '・只在按下打卡的那一刻記錄，不會持續追蹤\n'
        '・用途：確認出勤\n'
        '・管理員可以查看你的打卡位置\n\n'
        '按「同意」後，手機會詢問是否允許使用位置，請按「允許」。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('不同意'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('同意'),
        ),
      ],
    ),
  );
  if (ok == true) {
    store.giveLocationConsent(h);
    return true;
  }
  return false;
}

// ===================================================
// 狀態小標籤
// ===================================================
class StatusChip extends StatelessWidget {
  final WorkStatus status;
  final bool large;
  const StatusChip({super.key, required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: large ? 18 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ===================================================
// 登入頁
// ===================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isAdmin = false;
  bool hidePassword = true;
  final accountController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    accountController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() {
    final account = accountController.text.trim();
    final password = passwordController.text;

    if (account.isEmpty || password.isEmpty) {
      toast(context, '請輸入帳號和密碼');
      return;
    }
    if (password.length < 6) {
      toast(context, '密碼至少 6 碼');
      return;
    }

    if (isAdmin) {
      if (account != 'admin' || password != '123456') {
        toast(context, '管理員帳號或密碼錯誤');
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminHome()),
      );
    } else {
      final h = store.findByPhone(account);
      if (h == null) {
        toast(context, '查無此手機號碼，請先註冊');
        return;
      }
      if (h.password != password) {
        toast(context, '密碼錯誤');
        return;
      }
      if (!h.approved) {
        toast(context, '帳號審核中，請等管理員核准');
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HostessHome(hostess: h)),
      );
    }
  }

  Widget roleButton(String label, bool admin) {
    final selected = isAdmin == admin;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          isAdmin = admin;
          accountController.clear();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? gold : Colors.transparent,
            border: Border.all(color: gold),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : gold,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget inputBox({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              children: [
                const Icon(Icons.diamond_outlined, size: 80, color: gold),
                const SizedBox(height: 8),
                const Text(
                  appName,
                  style: TextStyle(
                    color: gold,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '出勤管理系統',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 36),
                Row(
                  children: [
                    roleButton('小姐登入', false),
                    const SizedBox(width: 12),
                    roleButton('管理員', true),
                  ],
                ),
                const SizedBox(height: 20),
                inputBox(
                  controller: accountController,
                  hint: isAdmin ? '管理員帳號' : '手機號碼',
                  icon: isAdmin ? Icons.person : Icons.phone_iphone,
                  keyboardType:
                      isAdmin ? TextInputType.text : TextInputType.phone,
                ),
                const SizedBox(height: 12),
                inputBox(
                  controller: passwordController,
                  hint: '密碼',
                  icon: Icons.lock,
                  obscure: hidePassword,
                  suffix: IconButton(
                    icon: Icon(
                      hidePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => hidePassword = !hidePassword),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      '登入',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (!isAdmin)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('還沒有帳號？',
                          style: TextStyle(color: Colors.white)),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterPage()),
                        ),
                        child: const Text(
                          '註冊',
                          style: TextStyle(
                            color: gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                const Text(
                  '測試帳號\n小姐：0911000001 ～ 0911000006\n管理員：admin\n密碼都是：123456',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================
// 小姐端
// ===================================================
class HostessHome extends StatefulWidget {
  final Hostess hostess;
  const HostessHome({super.key, required this.hostess});

  @override
  State<HostessHome> createState() => _HostessHomeState();
}

class _HostessHomeState extends State<HostessHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: blackBar(appName, actions: [logoutButton(context)]),
      // store 資料一變，這裡就自動重畫
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => tab == 0
            ? ClockPanel(hostess: widget.hostess)
            : RecordsView(hostess: widget.hostess),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tab,
        selectedItemColor: Colors.black,
        onTap: (i) => setState(() => tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.touch_app), label: '打卡'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '我的紀錄'),
        ],
      ),
    );
  }
}

// 打卡畫面
class ClockPanel extends StatelessWidget {
  final Hostess hostess;
  const ClockPanel({super.key, required this.hostess});

  // 取得打卡位置（第一次會先問是否同意）
  Future<LocationPoint?> locate(BuildContext context) async {
    final agreed = await ensureLocationConsent(context, hostess);
    if (!agreed || !context.mounted) return null;
    return getCurrentLocation(context);
  }

  String savedText(LocationPoint? loc) => loc == null ? '' : '（已記錄位置）';

  Future<void> doClockIn(BuildContext context) async {
    final loc = await locate(context);
    if (!context.mounted) return;

    // 有設定店家位置，而且要求必須在範圍內
    if (store.hasStoreLocation && store.requireInRange) {
      if (loc == null) {
        toast(context, '需要定位才能上班打卡');
        return;
      }
      final d = store.distanceToStore(loc)!;
      if (d > store.radius) {
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('不在店家範圍內'),
            content: Text(
                '你目前距離店家約 ${d.round()} 公尺，要在 ${store.radius.round()} 公尺內才能上班打卡。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        return;
      }
    }

    store.clockIn(hostess.id, loc: loc);
    toast(context, '上班打卡成功 ${fmtTime(DateTime.now())}${savedText(loc)}');
  }

  Future<void> doGoOut(BuildContext context) async {
    final place = await showDialog<String>(
      context: context,
      builder: (_) => const PlaceDialog(),
    );
    if (place == null || place.trim().isEmpty || !context.mounted) return;
    final loc = await locate(context);
    if (!context.mounted) return;
    store.goOut(hostess.id, place.trim(), loc: loc);
    toast(context, '外出：${place.trim()}${savedText(loc)}');
  }

  Future<void> doComeBack(BuildContext context) async {
    final loc = await locate(context);
    if (!context.mounted) return;
    store.comeBack(hostess.id, loc: loc);
    toast(context, '已回店${savedText(loc)}');
  }

  Future<void> doClockOut(BuildContext context, String message) async {
    final ok = await confirmDialog(context, '下班打卡', message);
    if (!ok || !context.mounted) return;
    final loc = await locate(context);
    if (!context.mounted) return;
    store.clockOut(hostess.id, loc: loc);
    toast(context, '下班打卡成功，辛苦了！${savedText(loc)}');
  }

  List<Widget> actionButtons(BuildContext context, WorkStatus status) {
    switch (status) {
      case WorkStatus.notIn:
        return [
          bigButton('上班打卡', Icons.login, Colors.green,
              () => doClockIn(context)),
          if (store.hasStoreLocation && store.requireInRange) ...[
            const SizedBox(height: 8),
            Text('需在店家 ${store.radius.round()} 公尺內打卡',
                style: const TextStyle(color: Colors.grey)),
          ],
        ];
      case WorkStatus.inStore:
        return [
          bigButton('外出', Icons.directions_car, Colors.orange,
              () => doGoOut(context)),
          const SizedBox(height: 12),
          bigButton('下班打卡', Icons.logout, Colors.red,
              () => doClockOut(context, '確定要下班了嗎？')),
        ];
      case WorkStatus.out:
        return [
          bigButton('回店', Icons.storefront, Colors.blue,
              () => doComeBack(context)),
          const SizedBox(height: 12),
          bigButton('直接下班', Icons.logout, Colors.red,
              () => doClockOut(context, '外出中直接下班？')),
        ];
      case WorkStatus.off:
        return [
          const Text('今天已下班，辛苦了！', style: TextStyle(fontSize: 16)),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = store.statusOf(hostess.id);
    final current = store.currentDispatch(hostess.id);
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '${hostess.name}，你好',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('今天 ${fmtDate(now)}',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                StatusChip(status: status, large: true),
                if (current != null) ...[
                  const SizedBox(height: 8),
                  Text('前往：${current.place}（${fmtTime(current.outTime)} 出發）'),
                ],
                const SizedBox(height: 20),
                ...actionButtons(context, status),
              ],
            ),
          ),
        ),
        sectionTitle('今日紀錄'),
        TodayTimeline(hostessId: hostess.id),
      ],
    );
  }
}

// 選外出地點的視窗
class PlaceDialog extends StatefulWidget {
  const PlaceDialog({super.key});

  @override
  State<PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<PlaceDialog> {
  String? selected;
  final otherController = TextEditingController();

  @override
  void dispose() {
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('要去哪裡？'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: store.commonPlaces.map((p) {
                return ChoiceChip(
                  label: Text(p),
                  selected: selected == p,
                  onSelected: (_) => setState(() {
                    selected = p;
                    otherController.clear();
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otherController,
              decoration: const InputDecoration(
                labelText: '或輸入其他地點',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() => selected = null),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final typed = otherController.text.trim();
            Navigator.pop(context, typed.isNotEmpty ? typed : selected);
          },
          child: const Text('出發'),
        ),
      ],
    );
  }
}

// 今日時間軸
class TodayTimeline extends StatelessWidget {
  final String hostessId;
  const TodayTimeline({super.key, required this.hostessId});

  @override
  Widget build(BuildContext context) {
    final events = store.eventsOnDay(hostessId, businessDay(DateTime.now()));
    if (events.isEmpty) {
      return const Card(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('今天還沒有紀錄', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return Card(
      color: Colors.white,
      child: Column(
        children: events.map((e) {
          final loc = e.loc;
          return ListTile(
            dense: true,
            leading: Icon(e.icon, color: e.color),
            title: Text(e.label, style: const TextStyle(fontSize: 15)),
            subtitle: Text(
              loc == null ? '沒有定位' : '📍 ${locationText(loc)}（點我看地圖）',
              style: TextStyle(
                color: isOutOfRange(loc) && e.label == '上班打卡'
                    ? Colors.red
                    : Colors.grey,
              ),
            ),
            trailing: Text(fmtTime(e.time),
                style: const TextStyle(fontSize: 15)),
            onTap: loc == null ? null : () => openMap(loc.lat, loc.lng),
          );
        }).toList(),
      ),
    );
  }
}

// 個人紀錄（小姐看自己的、管理員點進去看某個人的，都用這個）
class RecordsView extends StatelessWidget {
  final Hostess hostess;
  final List<Widget> header; // 放在最上面的額外內容（管理員頁用）
  const RecordsView({super.key, required this.hostess, this.header = const []});

  @override
  Widget build(BuildContext context) {
    final today = businessDay(DateTime.now());
    final monthStart = DateTime(today.year, today.month, 1);
    final monthEnd = DateTime(today.year, today.month + 1, 1);

    final atts = store.attendances
        .where((a) =>
            a.hostessId == hostess.id &&
            inRange(businessDay(a.clockIn), monthStart, monthEnd))
        .toList()
      ..sort((a, b) => b.clockIn.compareTo(a.clockIn));

    final dispatchCount = store.dispatches
        .where((d) =>
            d.hostessId == hostess.id &&
            inRange(businessDay(d.outTime), monthStart, monthEnd))
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...header,
        Text('${today.month} 月統計',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            statBox('出勤', '${atts.length} 天'),
            const SizedBox(width: 12),
            statBox('外出', '$dispatchCount 次', color: Colors.orange),
          ],
        ),
        sectionTitle('出勤明細'),
        if (atts.isEmpty)
          const Text('這個月還沒有出勤紀錄', style: TextStyle(color: Colors.grey)),
        ...atts.map((a) {
          final day = businessDay(a.clockIn);
          final ds = store.dispatchesOnDay(hostess.id, day);
          final timeText =
              '${fmtTime(a.clockIn)} ～ ${a.clockOut == null ? '上班中' : fmtTime(a.clockOut!)}';
          final outText = ds.isEmpty
              ? '沒有外出'
              : '外出 ${ds.length} 次：${ds.map((d) => d.place).join('、')}';
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(fmtDate(day),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$timeText\n$outText'),
              isThreeLine: true,
            ),
          );
        }),
      ],
    );
  }
}

// ===================================================
// 管理員端
// ===================================================
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    // 整個畫面都跟著 store 更新（名單上的待審核數字才會即時變）
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final pending = store.pendingHostesses.length;
        Widget body;
        if (tab == 0) {
          body = const AdminTodayView();
        } else if (tab == 1) {
          body = const AdminStatsView();
        } else {
          body = const RosterView();
        }
        return Scaffold(
          backgroundColor: pageBg,
          appBar: blackBar('$appName 管理', actions: [
            IconButton(
              icon: Icon(store.hasStoreLocation
                  ? Icons.location_on
                  : Icons.location_off),
              tooltip: '店家位置設定',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreSettingsPage()),
              ),
            ),
            logoutButton(context),
          ]),
          body: body,
          floatingActionButton: tab == 2
              ? FloatingActionButton(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  onPressed: () => editHostessDialog(context, null),
                  child: const Icon(Icons.person_add),
                )
              : null,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: tab,
            selectedItemColor: Colors.black,
            onTap: (i) => setState(() => tab = i),
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.today), label: '今日'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart), label: '統計'),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pending > 0,
                  label: Text('$pending'),
                  child: const Icon(Icons.people),
                ),
                label: '名單',
              ),
            ],
          ),
        );
      },
    );
  }
}

// 今日總覽
class AdminTodayView extends StatelessWidget {
  const AdminTodayView({super.key});

  @override
  Widget build(BuildContext context) {
    final today = businessDay(DateTime.now());
    final statuses = {
      for (final h in store.approvedHostesses) h.id: store.statusOf(h.id),
    };
    int count(WorkStatus s) => statuses.values.where((x) => x == s).length;
    final cameToday = statuses.length - count(WorkStatus.notIn);
    final todayDispatches =
        store.dispatches.where((d) => businessDay(d.outTime) == today).length;

    final sorted = store.approvedHostesses..sort((a, b) =>
        statuses[a.id]!.sortRank.compareTo(statuses[b.id]!.sortRank));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('今日 ${fmtDate(today)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            statBox('今日上班', '$cameToday 人', color: gold),
            const SizedBox(width: 8),
            statBox('在店', '${count(WorkStatus.inStore)} 人',
                color: Colors.green),
            const SizedBox(width: 8),
            statBox('外出中', '${count(WorkStatus.out)} 人',
                color: Colors.orange),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            statBox('已下班', '${count(WorkStatus.off)} 人',
                color: Colors.blueGrey),
            const SizedBox(width: 8),
            statBox('未到', '${count(WorkStatus.notIn)} 人', color: Colors.grey),
            const SizedBox(width: 8),
            statBox('今日外出', '$todayDispatches 次'),
          ],
        ),
        sectionTitle('每個人目前狀態'),
        ...sorted.map((h) {
          final status = statuses[h.id]!;
          final att = store.todayAttendance(h.id);
          final cur = store.currentDispatch(h.id);
          final n = store.dispatchesOnDay(h.id, today).length;
          String detail;
          switch (status) {
            case WorkStatus.notIn:
              detail = '尚未打卡';
              break;
            case WorkStatus.inStore:
              detail = '上班 ${fmtTime(att!.clockIn)}・外出 $n 次'
                  '${isOutOfRange(att.inLoc) ? '\n⚠ 上班打卡不在店家範圍' : ''}';
              break;
            case WorkStatus.out:
              detail = '外出中：${cur!.place}（${fmtTime(cur.outTime)} 出發）';
              break;
            case WorkStatus.off:
              detail =
                  '${fmtTime(att!.clockIn)} ～ ${fmtTime(att.clockOut!)}・外出 $n 次'
                  '${isOutOfRange(att.inLoc) ? '\n⚠ 上班打卡不在店家範圍' : ''}';
              break;
          }
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: status.color,
                foregroundColor: Colors.white,
                child: Text(h.name.isEmpty ? '?' : h.name.substring(0, 1)),
              ),
              title: Text(h.name),
              subtitle: Text(detail),
              trailing: StatusChip(status: status),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HostessDetailPage(hostess: h)),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// 管理員點進某位小姐看紀錄
class HostessDetailPage extends StatelessWidget {
  final Hostess hostess;
  const HostessDetailPage({super.key, required this.hostess});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: blackBar(hostess.name),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => RecordsView(
          hostess: hostess,
          header: [
            Text('手機：${hostess.phone}',
                style: const TextStyle(color: Colors.grey)),
            sectionTitle('今日紀錄'),
            TodayTimeline(hostessId: hostess.id),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// 統計
class AdminStatsView extends StatefulWidget {
  const AdminStatsView({super.key});

  @override
  State<AdminStatsView> createState() => _AdminStatsViewState();
}

class _AdminStatsViewState extends State<AdminStatsView> {
  String period = '近 7 天';

  @override
  Widget build(BuildContext context) {
    final today = businessDay(DateTime.now());
    DateTime start;
    DateTime end;
    if (period == '近 7 天') {
      start = DateTime(today.year, today.month, today.day - 6);
      end = DateTime(today.year, today.month, today.day + 1);
    } else if (period == '本月') {
      start = DateTime(today.year, today.month, 1);
      end = DateTime(today.year, today.month, today.day + 1);
    } else {
      start = DateTime(today.year, today.month - 1, 1);
      end = DateTime(today.year, today.month, 1);
    }

    final atts = store.attendances
        .where((a) => inRange(businessDay(a.clockIn), start, end))
        .toList();
    final ds = store.dispatches
        .where((d) => inRange(businessDay(d.outTime), start, end))
        .toList();

    // 每天上班人數（新的在上面）
    final days = <DateTime>[];
    for (var d = DateTime(end.year, end.month, end.day - 1);
        !d.isBefore(start);
        d = DateTime(d.year, d.month, d.day - 1)) {
      days.add(d);
    }
    final dailyCount = {
      for (final d in days)
        d: atts.where((a) => businessDay(a.clockIn) == d).length,
    };
    final maxCount =
        store.approvedHostesses.isEmpty ? 1 : store.approvedHostesses.length;
    final average = days.isEmpty ? 0 : atts.length / days.length;

    // 每個人
    final personal = store.approvedHostesses.map((h) {
      final dayCount = atts.where((a) => a.hostessId == h.id).length;
      final outCount = ds.where((d) => d.hostessId == h.id).length;
      return (name: h.name, days: dayCount, outs: outCount);
    }).toList()
      ..sort((a, b) => b.days.compareTo(a.days));

    // 外出地點
    final placeCount = <String, int>{};
    for (final d in ds) {
      placeCount[d.place] = (placeCount[d.place] ?? 0) + 1;
    }
    final places = placeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: ['近 7 天', '本月', '上月'].map((p) {
            return ChoiceChip(
              label: Text(p),
              selected: period == p,
              onSelected: (_) => setState(() => period = p),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            statBox('出勤人次', '${atts.length}', color: gold),
            const SizedBox(width: 8),
            statBox('平均每天', average.toStringAsFixed(1)),
            const SizedBox(width: 8),
            statBox('外出次數', '${ds.length}', color: Colors.orange),
          ],
        ),

        sectionTitle('每日上班人數'),
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: days.map((d) {
                final n = dailyCount[d]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 82, child: Text(fmtDate(d))),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: n / maxCount,
                          minHeight: 10,
                          color: gold,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text('$n 人', textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        sectionTitle('個人統計'),
        Card(
          color: Colors.white,
          child: Column(
            children: [
              const ListTile(
                dense: true,
                title: Text('名字', style: TextStyle(color: Colors.grey)),
                trailing: SizedBox(
                  width: 140,
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('出勤',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey))),
                      Expanded(
                          child: Text('外出',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey))),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              ...personal.map((p) => ListTile(
                    title: Text(p.name),
                    trailing: SizedBox(
                      width: 140,
                      child: Row(
                        children: [
                          Expanded(
                              child: Text('${p.days} 天',
                                  textAlign: TextAlign.center)),
                          Expanded(
                              child: Text('${p.outs} 次',
                                  textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),

        sectionTitle('外出地點'),
        Card(
          color: Colors.white,
          child: places.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('沒有外出紀錄', style: TextStyle(color: Colors.grey)),
                )
              : Column(
                  children: places
                      .map((e) => ListTile(
                            leading: const Icon(Icons.place,
                                color: Colors.orange),
                            title: Text(e.key),
                            trailing: Text('${e.value} 次',
                                style: const TextStyle(fontSize: 16)),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// 名單管理
class RosterView extends StatelessWidget {
  const RosterView({super.key});

  Widget avatar(Hostess h, Color color) {
    return CircleAvatar(
      backgroundColor: color,
      foregroundColor: Colors.black,
      child: Text(h.name.isEmpty ? '?' : h.name.substring(0, 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = store.pendingHostesses;
    final approved = store.approvedHostesses;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        // ---------- 待審核 ----------
        if (pending.isNotEmpty) ...[
          Text('新註冊待審核（${pending.length}）',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
          const SizedBox(height: 8),
          ...pending.map((h) => Card(
                color: Colors.orange.shade50,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: avatar(h, Colors.orange.shade200),
                  title: Text(h.name),
                  subtitle: Text(h.phone),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final ok = await confirmDialog(
                              context, '拒絕', '確定拒絕「${h.name}」的註冊？');
                          if (ok) store.removeHostess(h);
                        },
                        child: const Text('拒絕',
                            style: TextStyle(color: Colors.red)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          store.approveHostess(h);
                          toast(context, '已核准「${h.name}」');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('核准'),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 16),
        ],

        // ---------- 已核准 ----------
        Text('名單（共 ${approved.length} 人）',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (approved.isEmpty)
          const Text('還沒有人，按右下角＋新增',
              style: TextStyle(color: Colors.grey)),
        ...approved.map((h) => Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: avatar(h, gold),
                title: Text(h.name),
                subtitle: Text(h.phone),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => editHostessDialog(context, h),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final ok = await confirmDialog(
                            context, '刪除', '確定要刪除「${h.name}」嗎？\n（過去的紀錄會保留）');
                        if (ok) store.removeHostess(h);
                      },
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

// 新增／編輯小姐（管理員用）
Future<void> editHostessDialog(BuildContext context, Hostess? h) async {
  final nameController = TextEditingController(text: h?.name ?? '');
  final phoneController = TextEditingController(text: h?.phone ?? '');
  final passwordController = TextEditingController();
  String? error;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(h == null ? '新增小姐' : '編輯資料'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名字／代號'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '手機號碼（登入用）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: h == null ? '密碼（至少 6 碼）' : '新密碼（不改請留空）',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final password = passwordController.text;
              String? e;
              if (name.isEmpty) {
                e = '請輸入名字';
              } else if (!RegExp(r'^09\d{8}$').hasMatch(phone)) {
                e = '手機號碼格式錯誤（09 開頭，共 10 碼）';
              } else if (h == null && password.length < 6) {
                e = '密碼至少 6 碼';
              } else if (h != null &&
                  password.isNotEmpty &&
                  password.length < 6) {
                e = '新密碼至少 6 碼';
              } else {
                final other = store.findByPhone(phone);
                if (other != null && other != h) e = '這個手機號碼已經有人用了';
              }
              if (e != null) {
                setDialogState(() => error = e);
                return;
              }
              if (h == null) {
                store.addHostess(name, phone, password);
              } else {
                store.updateHostess(h, name, phone, password);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    ),
  );
}

// ===================================================
// 註冊頁（小姐自己註冊，管理員核准後才能登入）
// ===================================================
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool hidePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      toast(context, '請填寫所有欄位');
      return;
    }
    if (!RegExp(r'^09\d{8}$').hasMatch(phone)) {
      toast(context, '手機號碼格式錯誤（09 開頭，共 10 碼）');
      return;
    }
    if (password.length < 6) {
      toast(context, '密碼至少 6 碼');
      return;
    }
    if (password != confirmController.text) {
      toast(context, '兩次輸入的密碼不一樣');
      return;
    }
    if (store.findByPhone(phone) != null) {
      toast(context, '這個手機號碼已經註冊過了');
      return;
    }

    store.registerHostess(name, phone, password);

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('註冊成功'),
        content: const Text('已送出申請，管理員核准後就可以用手機號碼登入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context); // 回登入頁
  }

  Widget field(String label, TextEditingController controller,
      {bool obscure = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: blackBar('註冊帳號'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field('*名字／代號', nameController),
          field('*手機號碼（之後用來登入）', phoneController,
              keyboardType: TextInputType.phone),
          field('*密碼（至少 6 碼）', passwordController, obscure: hidePassword),
          field('*再輸入一次密碼', confirmController, obscure: hidePassword),
          Row(
            children: [
              Checkbox(
                value: !hidePassword,
                onChanged: (v) => setState(() => hidePassword = !(v ?? false)),
              ),
              const Text('顯示密碼'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: gold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('送出註冊',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '送出後需要管理員核准，核准後才能登入打卡。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ===================================================
// 店家位置設定（管理員）
// ===================================================
class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key});

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  late final latController =
      TextEditingController(text: store.storeLat?.toString() ?? '');
  late final lngController =
      TextEditingController(text: store.storeLng?.toString() ?? '');
  late final radiusController =
      TextEditingController(text: store.radius.round().toString());
  late bool requireInRange = store.requireInRange;
  String? accuracyNote;

  @override
  void dispose() {
    latController.dispose();
    lngController.dispose();
    radiusController.dispose();
    super.dispose();
  }

  Future<void> useCurrentLocation() async {
    final loc = await getCurrentLocation(context);
    if (loc == null || !mounted) return;
    setState(() {
      latController.text = loc.lat.toStringAsFixed(6);
      lngController.text = loc.lng.toStringAsFixed(6);
      accuracyNote = '本次定位誤差約 ${loc.accuracy.round()} 公尺'
          '${loc.accuracy > 50 ? '，建議到窗邊或門口再定位一次' : ''}';
    });
  }

  void save() {
    final latText = latController.text.trim();
    final lngText = lngController.text.trim();
    final radius = double.tryParse(radiusController.text.trim());

    if (radius == null || radius < 10 || radius > 5000) {
      toast(context, '範圍請輸入 10 ～ 5000 公尺');
      return;
    }

    double? lat;
    double? lng;
    if (latText.isNotEmpty || lngText.isNotEmpty) {
      lat = double.tryParse(latText);
      lng = double.tryParse(lngText);
      if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
        toast(context, '座標格式錯誤');
        return;
      }
    }

    store.setStoreSettings(lat, lng, radius, requireInRange);
    toast(context, lat == null ? '已儲存（未設定店家位置）' : '店家位置已儲存');
    Navigator.pop(context);
  }

  void clearLocation() {
    setState(() {
      latController.clear();
      lngController.clear();
      accuracyNote = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());

    return Scaffold(
      backgroundColor: pageBg,
      appBar: blackBar('店家位置設定'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('方法一：站在店裡，用手機定位',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  bigButton('用我現在的位置', Icons.my_location, gold,
                      useCurrentLocation),
                  if (accuracyNote != null) ...[
                    const SizedBox(height: 8),
                    Text(accuracyNote!,
                        style: const TextStyle(color: Colors.grey)),
                  ],
                  const SizedBox(height: 20),
                  const Text('方法二：手動輸入座標',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('在 Google 地圖長按店家位置，上方會出現座標，複製貼上即可。',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: '緯度（例如 25.033）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lngController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(
                            labelText: '經度（例如 121.565）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (lat != null && lng != null)
                        TextButton.icon(
                          onPressed: () => openMap(lat, lng),
                          icon: const Icon(Icons.map),
                          label: const Text('在地圖確認'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: clearLocation,
                        child: const Text('清除位置',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('打卡規則',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: radiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '允許範圍（公尺）',
                      helperText: '建議 100～200，室內 GPS 常有幾十公尺誤差',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('上班打卡必須在範圍內'),
                    subtitle: const Text('關閉的話，只記錄位置、不擋打卡'),
                    value: requireInRange,
                    onChanged: (v) => setState(() => requireInRange = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: gold,
              ),
              child: const Text('儲存設定',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

