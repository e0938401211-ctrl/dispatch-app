import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(), // App 打開先看到登入頁
    );
  }
}

// ===================================================
// 主框架：上方標題列 + 底部分頁，負責切換「派車首頁」和「會員中心」
// ===================================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int currentIndex = 0; // 0 = 派車首頁，1 = 會員中心
  bool isOnline = false;
  int balance = 70;
  int violations = 0;

  void toggleOnline() {
    setState(() {
      isOnline = !isOnline;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isOnline ? '已上線，等待派單' : '已切換為休息'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car),
            SizedBox(width: 8),
            Text('24h派車'),
          ],
        ),
      ),

      // IndexedStack：切換分頁時，另一頁的狀態不會消失
      body: IndexedStack(
        index: currentIndex,
        children: [
          DispatchHome(
            isOnline: isOnline,
            balance: balance,
            violations: violations,
            onToggle: toggleOnline,
          ),
          const MemberCenter(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.black,
        onTap: (index) {
          setState(() {
            currentIndex = index; // 點哪個分頁就切到哪個
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car),
            label: '派車首頁',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '會員中心',
          ),
        ],
      ),
    );
  }
}

// ===================================================
// 派車首頁
// ===================================================
class DispatchHome extends StatelessWidget {
  final bool isOnline;
  final int balance;
  final int violations;
  final VoidCallback onToggle;

  const DispatchHome({
    super.key,
    required this.isOnline,
    required this.balance,
    required this.violations,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: onToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnline ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(isOnline ? '點我休息' : '點我上線'),
              ),
              const SizedBox(height: 8),
              Text(
                '我的狀態：${isOnline ? '上線中' : '休息中'}　目前餘額：$balance',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '違規次數：$violations',
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.wifi_tethering : Icons.bolt,
                  size: 40,
                  color: isOnline ? Colors.green : Colors.black,
                ),
                const SizedBox(height: 8),
                Text(
                  isOnline ? '等待派單中…' : '您現在休息中~',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===================================================
// 會員中心
// ===================================================
class MemberCenter extends StatelessWidget {
  const MemberCenter({super.key});

  // 一行選單（文字 + 右箭頭）
  Widget menuItem(String title, VoidCallback onTap) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          ListTile(
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
          const Divider(height: 1, indent: 16),
        ],
      ),
    );
  }

  void showNotReady(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「$name」還沒做，之後再加'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // 跳出確認視窗
  void showConfirm(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // 回到登入頁，並清掉之前所有頁面（按返回鍵也回不去）
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // 上方姓名、狀態
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('姓名：Jason Test', style: TextStyle(fontSize: 16)),
              SizedBox(height: 6),
              Text('狀態：登入中', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        menuItem('基本資料', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
        }),
        menuItem('儲值紀錄', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TopUpRecordsPage()),
          );
        }),
        menuItem('近期接單', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecentOrdersPage()),
          );
        }),

        const SizedBox(height: 16),

        // 登出、刪除帳號按鈕
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => showConfirm(context, '登出', '確定要登出嗎？'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('登出', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => showConfirm(
                    context,
                    '刪除帳號',
                    '刪除後資料無法復原，確定要刪除嗎？',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('刪除帳號', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===================================================
// 基本資料頁（從會員中心點進來）
// ===================================================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String gender = '男';

  // 一個輸入欄位（標題 + 輸入框）
  Widget field(String label, String value, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: value,
            obscureText: obscure,
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('基本資料'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field('*真實姓名', 'Jason Test'),
          field('*暱稱', 'Jason NickName'),
          field('*手機號碼', '0912585506'),
          field('*密碼', '', obscure: true),
          field('身份證字號', 'N12459'),

          const Text('性別'),
          const SizedBox(height: 6),
          Row(
            children: [
              ChoiceChip(
                label: const Text('男'),
                selected: gender == '男',
                onSelected: (_) => setState(() => gender = '男'),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('女'),
                selected: gender == '女',
                onSelected: (_) => setState(() => gender = '女'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          field('*車號(ABC-1234,請填 1234)', 'ABC-123'),
          field('顏色', 'White'),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('（測試）資料已儲存')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('儲存', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
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
  // controller 用來讀取輸入框裡打的字
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool hidePassword = true;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void login() {
    final phone = phoneController.text.trim();
    final password = passwordController.text;

    // 檢查輸入（之後會改成真的去 Firebase 驗證帳密）
    if (phone.isEmpty || password.isEmpty) {
      showMessage('請輸入手機號碼和密碼');
      return;
    }
    if (!RegExp(r'^09\d{8}$').hasMatch(phone)) {
      showMessage('手機號碼格式錯誤（09 開頭，共 10 碼）');
      return;
    }
    if (password.length < 6) {
      showMessage('密碼至少 6 碼');
      return;
    }

    // 通過檢查 → 換到主畫面（pushReplacement：按返回不會回到登入頁）
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainPage()),
    );
  }

  // 白色圓角輸入框
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
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                const Icon(Icons.directions_car, size: 100, color: Colors.white),
                const Text(
                  '24h派車',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 60),
                inputBox(
                  controller: phoneController,
                  hint: '手機號碼',
                  icon: Icons.phone_iphone,
                  keyboardType: TextInputType.phone,
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
                    onPressed: () {
                      setState(() => hidePassword = !hidePassword);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: login,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('登入', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('還沒有帳號？', style: TextStyle(color: Colors.white)),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      child: const Text(
                        '註冊',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
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
// 註冊頁
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

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void register() {
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      showMessage('請填寫所有欄位');
      return;
    }
    if (!RegExp(r'^09\d{8}$').hasMatch(phoneController.text.trim())) {
      showMessage('手機號碼格式錯誤（09 開頭，共 10 碼）');
      return;
    }
    if (passwordController.text.length < 6) {
      showMessage('密碼至少 6 碼');
      return;
    }
    if (passwordController.text != confirmController.text) {
      showMessage('兩次輸入的密碼不一樣');
      return;
    }

    showMessage('（測試）註冊成功，請登入');
    Navigator.pop(context); // 回到登入頁
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('註冊'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field('*真實姓名', nameController),
          field('*手機號碼', phoneController, keyboardType: TextInputType.phone),
          field('*密碼（至少 6 碼）', passwordController, obscure: true),
          field('*再輸入一次密碼', confirmController, obscure: true),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('註冊', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================
// 訂單資料（一筆訂單長什麼樣子）
// ===================================================
class Order {
  final String id;
  final String time;
  final String pickup; // 上車地點
  final String dropoff; // 下車地點
  final String passenger;
  final int fare; // 車資
  final String status; // 已完成 / 已取消
  final String note;

  const Order({
    required this.id,
    required this.time,
    required this.pickup,
    required this.dropoff,
    required this.passenger,
    required this.fare,
    required this.status,
    this.note = '',
  });
}

// 假資料：之後會改成從 Firebase 讀取
const List<Order> fakeOrders = [
  Order(
    id: 'A20261101003',
    time: '2026/11/01 14:20',
    pickup: '台北車站 東三門',
    dropoff: '松山機場 第一航廈',
    passenger: '王先生',
    fare: 320,
    status: '已完成',
  ),
  Order(
    id: 'A20261101002',
    time: '2026/11/01 10:05',
    pickup: '信義區 市府路 45 號',
    dropoff: '內湖科學園區 瑞光路',
    passenger: '陳小姐',
    fare: 410,
    status: '已完成',
    note: '有一件大行李',
  ),
  Order(
    id: 'A20261101001',
    time: '2026/11/01 08:30',
    pickup: '中山區 南京東路二段',
    dropoff: '大安森林公園',
    passenger: '林先生',
    fare: 0,
    status: '已取消',
    note: '乘客取消',
  ),
  Order(
    id: 'A20261031004',
    time: '2026/10/31 22:15',
    pickup: '西門町 捷運 6 號出口',
    dropoff: '板橋車站',
    passenger: '張小姐',
    fare: 380,
    status: '已完成',
  ),
  Order(
    id: 'A20261031003',
    time: '2026/10/31 17:40',
    pickup: '南港展覽館',
    dropoff: '汐止 大同路',
    passenger: '李先生',
    fare: 290,
    status: '已完成',
  ),
];

// ===================================================
// 近期接單列表
// ===================================================
class RecentOrdersPage extends StatefulWidget {
  const RecentOrdersPage({super.key});

  @override
  State<RecentOrdersPage> createState() => _RecentOrdersPageState();
}

class _RecentOrdersPageState extends State<RecentOrdersPage> {
  String filter = '全部'; // 全部 / 已完成 / 已取消

  @override
  Widget build(BuildContext context) {
    // 依篩選條件挑出要顯示的訂單
    final orders = filter == '全部'
        ? fakeOrders
        : fakeOrders.where((o) => o.status == filter).toList();

    // 統計：完成幾筆、總收入多少
    final completed = fakeOrders.where((o) => o.status == '已完成').toList();
    final income = completed.fold<int>(0, (sum, o) => sum + o.fare);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('近期接單'),
      ),
      body: Column(
        children: [
          // 上方統計
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                summaryBox('完成趟數', '${completed.length} 趟'),
                summaryBox('總收入', '\$$income'),
              ],
            ),
          ),

          // 篩選按鈕
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: ['全部', '已完成', '已取消'].map((name) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: filter == name,
                    onSelected: (_) => setState(() => filter = name),
                  ),
                );
              }).toList(),
            ),
          ),

          // 訂單列表
          Expanded(
            child: orders.isEmpty
                ? const Center(child: Text('沒有訂單'))
                : ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return OrderCard(order: orders[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget summaryBox(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// 一張訂單卡片
class OrderCard extends StatelessWidget {
  final Order order;
  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == '已取消';

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailPage(order: order)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 時間 + 狀態
              Row(
                children: [
                  Text(order.time, style: const TextStyle(color: Colors.grey)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cancelled ? Colors.grey : Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.status,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              placeRow(Icons.circle, Colors.green, order.pickup),
              const SizedBox(height: 4),
              placeRow(Icons.location_on, Colors.red, order.dropoff),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  cancelled ? '—' : '\$${order.fare}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 上車 / 下車地點那一行
Widget placeRow(IconData icon, Color color, String text) {
  return Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
    ],
  );
}

// ===================================================
// 訂單明細
// ===================================================
class OrderDetailPage extends StatelessWidget {
  final Order order;
  const OrderDetailPage({super.key, required this.order});

  Widget row(String label, String value) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('訂單明細'),
      ),
      body: ListView(
        children: [
          row('訂單編號', order.id),
          const Divider(height: 1),
          row('時間', order.time),
          const Divider(height: 1),
          row('狀態', order.status),
          const SizedBox(height: 8),
          row('上車地點', order.pickup),
          const Divider(height: 1),
          row('下車地點', order.dropoff),
          const Divider(height: 1),
          row('乘客', order.passenger),
          const SizedBox(height: 8),
          row('車資', order.status == '已取消' ? '—' : '\$${order.fare}'),
          if (order.note.isNotEmpty) ...[
            const Divider(height: 1),
            row('備註', order.note),
          ],
        ],
      ),
    );
  }
}

// ===================================================
// 儲值 / 扣款紀錄資料
// ===================================================
class BalanceRecord {
  final String time;
  final String type; // 儲值 / 扣款
  final String description;
  final int amount; // 正數 = 加錢，負數 = 扣錢
  final int balanceAfter; // 這筆之後的餘額

  const BalanceRecord({
    required this.time,
    required this.type,
    required this.description,
    required this.amount,
    required this.balanceAfter,
  });
}

// 假資料（新的在上面）：最後餘額 70，跟派車首頁一致
const List<BalanceRecord> fakeBalanceRecords = [
  BalanceRecord(
    time: '2026/11/01 14:25',
    type: '扣款',
    description: '接單抽成 A20261101003',
    amount: -20,
    balanceAfter: 70,
  ),
  BalanceRecord(
    time: '2026/11/01 10:10',
    type: '扣款',
    description: '接單抽成 A20261101002',
    amount: -20,
    balanceAfter: 90,
  ),
  BalanceRecord(
    time: '2026/11/01 09:00',
    type: '儲值',
    description: '銀行轉帳儲值',
    amount: 100,
    balanceAfter: 110,
  ),
  BalanceRecord(
    time: '2026/10/31 22:20',
    type: '扣款',
    description: '接單抽成 A20261031004',
    amount: -20,
    balanceAfter: 10,
  ),
  BalanceRecord(
    time: '2026/10/31 17:45',
    type: '扣款',
    description: '接單抽成 A20261031003',
    amount: -20,
    balanceAfter: 30,
  ),
  BalanceRecord(
    time: '2026/10/30 12:00',
    type: '儲值',
    description: '現金儲值（派車中心）',
    amount: 50,
    balanceAfter: 50,
  ),
];

// ===================================================
// 儲值紀錄頁
// ===================================================
class TopUpRecordsPage extends StatefulWidget {
  const TopUpRecordsPage({super.key});

  @override
  State<TopUpRecordsPage> createState() => _TopUpRecordsPageState();
}

class _TopUpRecordsPageState extends State<TopUpRecordsPage> {
  String filter = '全部'; // 全部 / 儲值 / 扣款

  // 「我要儲值」說明視窗（真的金流之後再做）
  void showTopUpInfo() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('我要儲值'),
        content: const Text(
          '目前請用以下方式儲值：\n\n'
          '1. 銀行轉帳後，聯絡派車中心核對\n'
          '2. 到派車中心現金儲值\n\n'
          '儲值完成後，餘額會自動更新。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = filter == '全部'
        ? fakeBalanceRecords
        : fakeBalanceRecords.where((r) => r.type == filter).toList();

    // 最新一筆的餘額就是目前餘額
    final currentBalance =
        fakeBalanceRecords.isEmpty ? 0 : fakeBalanceRecords.first.balanceAfter;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('儲值紀錄'),
      ),
      body: Column(
        children: [
          // 上方餘額
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const Text('目前餘額', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '\$$currentBalance',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: showTopUpInfo,
                  icon: const Icon(Icons.add),
                  label: const Text('我要儲值'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 篩選
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: ['全部', '儲值', '扣款'].map((name) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: filter == name,
                    onSelected: (_) => setState(() => filter = name),
                  ),
                );
              }).toList(),
            ),
          ),

          // 紀錄列表
          Expanded(
            child: records.isEmpty
                ? const Center(child: Text('沒有紀錄'))
                : ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final r = records[index];
                      final isIncome = r.amount > 0;
                      return Container(
                        color: Colors.white,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(r.description),
                          subtitle: Text(r.time),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isIncome ? '+${r.amount}' : '${r.amount}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isIncome ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(
                                '餘額 ${r.balanceAfter}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
