import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:translator/translator.dart'; // ÇEVİRİ PAKETİ EKLENDİ
import 'dart:convert';
import 'dart:math';
import 'firebase_options.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔥 WEB BAĞLANTI HATALARINI COZEN ZIRHLI AYARLAR 🔥
// Web bağlantı hatalarını ve QUIC protokolünü ezen kesin çözüm:
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  // Altı çizilen parametreyi doğrudan Firestore'un temel ayarlarına enjekte ediyoruz:
  FirebaseFirestore.instance.clearPersistence();

  runApp(const KitchyApp());
}

class KitchyApp extends StatelessWidget {
  const KitchyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kitchy',
      theme: ThemeData(
        primaryColor: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: const Color(0xFFD5E8D4),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: FirebaseAuth.instance.currentUser == null ? const LoginScreen() : const MainNavigationScreen(),
    );
  }
}

// -------------------------------------------------------------------
// ANA NAVİGASYON (Sepet Eklendi)
// -------------------------------------------------------------------
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0; // Keşfet sayfasında başlasın

  final List<Widget> _pages = [
    const DiscoverPage(),
    const MyKitchenPage(),
    const PlanningPage(),
    const FavoritesPage(),
    const ShoppingListPage(), // 🛒 ALIŞVERİŞ SAYFASI BURAYA EKLENDİ
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)]),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF2E7D32),
            unselectedItemColor: Colors.grey.shade400,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Keşfet'),
              BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_outlined), label: 'Mutfağım'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Planlama'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), label: 'Favoriler'),
              BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), label: 'Liste'), // 🛒 SEPET İKONU BURAYA EKLENDİ
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}
// -------------------------------------------------------------------
// 🥗 MUTFAĞIM SAYFASI (YAPAY ZEKA SENİN BIRAKTIĞIN GİBİ DURUYOR)
// -------------------------------------------------------------------
class MyKitchenPage extends StatelessWidget {
  const MyKitchenPage({super.key});

 // 1. ANA FONKSİYON: ÇEVRİMDİŞİ ŞEF SİLİNDİ, DİREKT GEMİNİ PAKETİ KULLANILIYOR
  Future<void> _generateRecipeWithAI(BuildContext context, String uid) async {
    final snapshot = await FirebaseFirestore.instance.collection('user_materials').where('uid', isEqualTo: uid).get();
    
    if (snapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dolabın boş! Önce malzeme eklemelisin 🥕')));
      return;
    }

    List<String> materials = snapshot.docs.map((doc) => doc['name'].toString()).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
    );

    try {
      // 🔥 YENİ ÜRETTİĞİN ŞİFREYİ BURAYA YAPIŞTIR (Eski sızan şifreyi kullanma) 🔥
      const apiKey = 'AQ.Ab8RN6LnMS7Aq2ekpuzj2shAD2DM_ZrArYxEN6B8nAucNHCKYw'; 
      
      final prompt = '''
      Sen profesyonel ve analitik düşünen bir aşçısın. Mutfağımda şu malzemeler var: ${materials.join(', ')}.
      Bana bu malzemeleri kullanarak yapabileceğim pratik ve lezzetli 1 tarif öner.
      
      Lütfen cevabına tam olarak şu formatta başla:
      🎯 EŞLEŞME ORANI: %X
      Ardından sırasıyla; Yemeğin Adı:, Malzemeler: (Evde olanların yanına "✅", eksik olanların yanına "🛒" koy), Yapılışı:
      ''';

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      if (context.mounted) Navigator.pop(context);

      if (response.text != null && response.text!.isNotEmpty) {
        _showRecipeDialog(context, response.text!, isOffline: false);
      } else {
        throw Exception('Gemini boş cevap döndürdü.');
      }

    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
      }
      
      // ÇEVRİMDİŞİ ZIRVALIĞI TAMAMEN SİLİNDİ, DİREKT GERÇEK HATAYI EKRANA BASIYOR
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🚨 API Bağlantı Hatası', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(child: Text(e.toString())),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))
            ],
          ),
        );
      }
    }
  }
  // 🔥 EKRANA TARİF PENCERESİNİ ÇIKARAN EKSİK FONKSİYON 🔥
  void _showRecipeDialog(BuildContext context, String textResponse, {required bool isOffline}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isOffline ? Icons.wifi_off : Icons.auto_awesome, color: isOffline ? Colors.grey : Colors.orange),
            const SizedBox(width: 10),
            Text(
              isOffline ? 'Çevrimdışı Şef Önerisi' : 'AI Şefin Önerisi', 
              style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(textResponse, style: const TextStyle(fontSize: 15, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Kapat', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  // 2. WEB UYUMLU ZIRHLI ÇEVRİMDİŞİ ŞEF ALGORİTMASI
  Future<void> _runOfflineChef(BuildContext context, List<String> myMaterials) async {
    try {
      // Flutter Web önbelleği boşaltabileceği için ilk olarak normal get() deniyoruz, 
      // eğer internet yoksa otomatik olarak yakalayacak.
      QuerySnapshot<Map<String, dynamic>> recipesSnapshot;
      try {
        recipesSnapshot = await FirebaseFirestore.instance.collection('community_recipes').get();
      } catch (_) {
        // Tamamen çevrimdışı ise zorunlu olarak cache'e yönlendiriyoruz
        recipesSnapshot = await FirebaseFirestore.instance.collection('community_recipes').get(const GetOptions(source: Source.cache));
      }
      
      // HAFIZA VEYA VERİTABANI DOLUYSA ANALİZ ET
      if (recipesSnapshot.docs.isNotEmpty) {
        Map<String, dynamic>? bestRecipe;
        double bestMatchPercentage = 0.0;
        List<String> finalMatched = [];
        List<String> finalMissing = [];

        for (var doc in recipesSnapshot.docs) {
          var data = doc.data(); 
          String ingredientsStr = data['ingredients'] ?? ''; 
          List<String> recipeIngredients = ingredientsStr.split(',').map((e) => e.trim()).toList();

          int matchCount = 0;
          List<String> currentMatched = [];
          List<String> currentMissing = [];

          for (var recipeMat in recipeIngredients) {
            bool found = false;
            for (var myMat in myMaterials) {
              if (recipeMat.toLowerCase().contains(myMat.toLowerCase())) {
                found = true;
                break;
              }
            }
            if (found) { matchCount++; currentMatched.add(recipeMat); } 
            else { currentMissing.add(recipeMat); }
          }

          double percentage = recipeIngredients.isNotEmpty ? (matchCount / recipeIngredients.length) * 100 : 0;
          
          if (percentage >= bestMatchPercentage) {
            bestMatchPercentage = percentage;
            bestRecipe = data;
            finalMatched = currentMatched;
            finalMissing = currentMissing;
          }
        }

        if (bestRecipe != null) {
          String offlineResponse = "🎯 EŞLEŞME ORANI: %${bestMatchPercentage.toInt()}\n\n";
          offlineResponse += "Yemeğin Adı: ${bestRecipe['mealName'] ?? 'İsimsiz Yemek'}\n\n";
          offlineResponse += "**Malzemeler:**\n";
          for (var m in finalMatched) { offlineResponse += "* $m ✅\n"; }
          for (var m in finalMissing) { offlineResponse += "* $m 🛒\n"; }
          offlineResponse += "\n**Yapılışı:**\n${bestRecipe['instructions'] ?? 'Tarif adımları bulunamadı.'}";
          
          if (context.mounted) _showRecipeDialog(context, offlineResponse, isOffline: true);
          return;
        }
      }
      
      // 🔥 ACİL DURUM PLANI (Yedek Tarif): Tarayıcı hafızası tamamen sıfırsa çökmesin diye bunu gösteriyoruz
      String fallbackResponse = "🎯 EŞLEŞME ORANI: %100\n\n";
      fallbackResponse += "Yemeğin Adı: Pratik Ev Makarnası 🍝\n\n";
      fallbackResponse += "**Malzemeler:**\n";
      for (var mat in myMaterials) { fallbackResponse += "* $mat ✅\n"; }
      fallbackResponse += "\n**Yapılışı:**\nŞu an ne internete ne de yerel hafızaya ulaşılabildi. Ancak elindeki bu malzemeleri (${myMaterials.join(', ')}) haşlanmış bir makarnayla veya zeytinyağında soteleyerek hızlıca lezzetli bir öğün hazırlayabilirsin!";
      
      if (context.mounted) _showRecipeDialog(context, fallbackResponse, isOffline: true);

    } catch (e) {
      debugPrint("Çevrimdışı şef ölümcül hata: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Mutfağım')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('user_materials').where('uid', isEqualTo: user?.uid).orderBy('timestamp', descending: true).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                if(docs.isEmpty) return const Center(child: Text("Henüz malzeme yok 🥕", style: TextStyle(fontSize: 18, color: Colors.grey)));
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.eco, color: Colors.green),
                        title: Text(data['name'] ?? ''), 
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => FirebaseFirestore.instance.collection('user_materials').doc(docs[index].id).delete())
                      )
                    );
                  },
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]
            ),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1F26), 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                icon: const Icon(Icons.auto_awesome, color: Colors.orange),
                label: const Text('✨ Elimdekilerle Ne Pişirebilirim?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                onPressed: () {
                  if (user != null) {
                    _generateRecipeWithAI(context, user.uid);
                  }
                },
              ),
            ),
          )
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF2E7D32),
          onPressed: () {
            TextEditingController c = TextEditingController();
            showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Ekle'), content: TextField(controller: c, decoration: const InputDecoration(hintText: "Örn: Domates")), actions: [ElevatedButton(onPressed: () { FirebaseFirestore.instance.collection('user_materials').add({'name': c.text, 'uid': user?.uid, 'timestamp': FieldValue.serverTimestamp()}); Navigator.pop(context); }, child: const Text('Ekle'))]));
          }, 
          child: const Icon(Icons.add, color: Colors.white)
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// 📅 PLANLAMA (TAKVİM) SAYFASI (Açılır Liste Menüsü Eklendi)
// -------------------------------------------------------------------
class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  // --- YEMEK ÖNERİ LİSTELERİ ---
  final List<String> _kahvaltiOnerileri = ['Menemen', 'Sahanda Yumurta', 'Pankek', 'Omlet', 'Tost', 'Simit', 'Krep', 'Yulaf Lapası', 'Mıhlama', 'Sucuklu Yumurta', 'Gözleme', 'Kahvaltı Tabağı', 'Boyoz', 'Pişi'];
  final List<String> _ogleYemegiOnerileri = ['Makarna', 'Tavuk Sote', 'Hamburger', 'Pizza', 'Sezar Salata', 'Mercimek Çorbası', 'Kuru Fasulye', 'Pilav', 'Izgara Tavuk', 'Döner', 'Lahmacun', 'Tavuk Dürüm', 'Mantı'];
  final List<String> _aksamYemegiOnerileri = ['Karnıyarık', 'Fırında Tavuk', 'Balık Izgara', 'Köfte Patates', 'İskender', 'Et Sote', 'Türlü', 'Musakka', 'Lazanya', 'Fırın Somon', 'Güveç', 'Kremalı Mantar Çorbası'];

  void _showAddPlanDialog(BuildContext context, String dateKey, {Map<String, dynamic>? existingPlan, String? docId}) {
    TextEditingController breakfast = TextEditingController(text: existingPlan?['breakfast'] ?? '');
    TextEditingController lunch = TextEditingController(text: existingPlan?['lunch'] ?? '');
    TextEditingController dinner = TextEditingController(text: existingPlan?['dinner'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFF1F8E9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existingPlan == null ? 'Plan Oluştur' : 'Planı Düzenle', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('dd MMM yyyy').format(_selectedDay!), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _planTextField(breakfast, 'Kahvaltı', Icons.free_breakfast, _kahvaltiOnerileri),
              const SizedBox(height: 10),
              _planTextField(lunch, 'Öğle Yemeği', Icons.lunch_dining, _ogleYemegiOnerileri),
              const SizedBox(height: 10),
              _planTextField(dinner, 'Akşam Yemeği', Icons.dinner_dining, _aksamYemegiOnerileri),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              final data = {'uid': user?.uid, 'date': dateKey, 'breakfast': breakfast.text.trim(), 'lunch': lunch.text.trim(), 'dinner': dinner.text.trim(), 'timestamp': FieldValue.serverTimestamp()};
              if (docId == null) { 
                await FirebaseFirestore.instance.collection('user_plans').add(data); 
              } else { 
                await FirebaseFirestore.instance.collection('user_plans').doc(docId).update(data); 
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // --- YENİ PLAN TEXTFIELD (Açılır Liste Butonlu) ---
  Widget _planTextField(TextEditingController externalController, String label, IconData icon, List<String> suggestions) {
    return TextField(
      controller: externalController,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),
        
        // İŞTE BURAYA EKLENDİ: Sağ tarafa eklenen açılır liste (dropdown) butonu
        suffixIcon: PopupMenuButton<String>(
          icon: const Icon(Icons.arrow_drop_down_circle, color: Color(0xFF4CAF50)),
          tooltip: 'Listeden Seç',
          onSelected: (String value) {
            externalController.text = value; // Listeden seçileni anında kutuya yaz
          },
          itemBuilder: (BuildContext context) {
            return suggestions.map((String choice) {
              return PopupMenuItem<String>(
                value: choice,
                child: Text(choice, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              );
            }).toList();
          },
        ),
        
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String selectedDateKey = DateFormat('yyyy-MM-dd').format(_selectedDay!);

    return Scaffold(
      appBar: AppBar(title: const Text('Haftalık Plan')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) { setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }); },
              calendarFormat: CalendarFormat.week, availableCalendarFormats: const {CalendarFormat.week: 'Hafta'},
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              calendarStyle: const CalendarStyle(selectedDecoration: BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle), todayDecoration: BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('user_plans').where('uid', isEqualTo: user?.uid).where('date', isEqualTo: selectedDateKey).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
                if (snapshot.hasError) return Center(child: SelectableText('İndeks Hatası! Firebase konsolundan indeks oluşturun.\n${snapshot.error}', style: const TextStyle(color: Colors.red)));

                var docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 70, color: Colors.grey.shade400), const SizedBox(height: 15),
                        Text('${DateFormat('dd MMM yyyy').format(_selectedDay!)}\niçin plan yapılmamış.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), icon: const Icon(Icons.add), label: const Text('Günlük Plan Oluştur'), onPressed: () => _showAddPlanDialog(context, selectedDateKey)),
                      ],
                    ),
                  );
                }

                var planData = docs.first.data() as Map<String, dynamic>; String docId = docs.first.id;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('dd MMMM yyyy').format(_selectedDay!), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))), IconButton(icon: const Icon(Icons.edit, color: Color(0xFF4CAF50)), onPressed: () => _showAddPlanDialog(context, selectedDateKey, existingPlan: planData, docId: docId))]),
                    const SizedBox(height: 10),
                    _mealCard('Kahvaltı', Icons.free_breakfast, planData['breakfast']), _mealCard('Öğle Yemeği', Icons.lunch_dining, planData['lunch']), _mealCard('Akşam Yemeği', Icons.dinner_dining, planData['dinner']),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _mealCard(String title, IconData icon, String? meal) {
    bool isEmpty = meal == null || meal.trim().isEmpty;
    return Card(margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFD5E8D4), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF2E7D32))), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)), subtitle: Text(isEmpty ? 'Belirlenmedi' : meal, style: TextStyle(fontSize: 16, fontWeight: isEmpty ? FontWeight.normal : FontWeight.bold, color: isEmpty ? Colors.grey : Colors.black87))));
  }
}

// -------------------------------------------------------------------
// 👤 PROFİL SAYFASI (Oyunlaştırma, Rütbe ve Liderlik Tablosu Eklendi)
// -------------------------------------------------------------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // --- PUAN VE RÜTBE HESAPLAMA MANTIĞI ---
  String _getRank(int points) {
    if (points < 50) return 'Çırak Aşçı 🍳';
    if (points < 150) return 'Yetenekli Şef 🔪';
    if (points < 300) return 'Gurme 🍷';
    if (points < 600) return 'Master Şef 👑';
    return 'Mutfak Efsanesi 🌟';
  }

  // --- LİDERLİK TABLOSU PENCERESİ ---
  void _showLeaderboard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: Colors.orange, size: 30),
                  SizedBox(width: 10),
                  Text('Liderlik Tablosu', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                ],
              ),
              const Divider(height: 30, thickness: 2),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
                    if (snapshot.hasError) return const Center(child: Text('Hata oluştu.'));

                    var users = snapshot.data?.docs.toList() ?? [];
                    
                    // İndeks hatası almamak için sıralamayı kod içinde yapıyoruz
                    users.sort((a, b) {
                      int pointsA = (a.data() as Map<String, dynamic>)['points'] ?? 0;
                      int pointsB = (b.data() as Map<String, dynamic>)['points'] ?? 0;
                      return pointsB.compareTo(pointsA); // Yüksek puandan düşüğe sırala
                    });

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        var userData = users[index].data() as Map<String, dynamic>;
                        int pts = userData['points'] ?? 0;
                        bool isMe = users[index].id == FirebaseAuth.instance.currentUser?.uid;

                        return Card(
                          color: isMe ? const Color(0xFFE8F5E9) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isMe ? const Color(0xFF2E7D32) : Colors.grey.shade200,
                              child: Text('${index + 1}', style: TextStyle(color: isMe ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(userData['name'] ?? 'İsimsiz', style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Text(_getRank(pts), style: const TextStyle(color: Colors.orange, fontSize: 12)),
                            trailing: Text('$pts Puan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32))),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // --- BİLGİLERİ GÜNCELLEME PENCERESİ ---
  void _showEditProfileDialog(BuildContext context, String currentName, String currentAge, String uid) {
    TextEditingController nameController = TextEditingController(text: currentName == "İsimsiz" ? "" : currentName);
    TextEditingController ageController = TextEditingController(text: currentAge == "0" ? "" : currentAge);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFF1F8E9), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
        title: const Text('Bilgileri Güncelle', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nameController, decoration: InputDecoration(labelText: 'Ad Soyad', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))), const SizedBox(height: 15), TextField(controller: ageController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Yaş', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white), onPressed: () async {
            if (nameController.text.isNotEmpty) { await FirebaseFirestore.instance.collection('users').doc(uid).set({'name': nameController.text.trim(), 'age': int.tryParse(ageController.text.trim()) ?? 0}, SetOptions(merge: true)); if (dialogContext.mounted) Navigator.pop(dialogContext); }
          }, child: const Text('Kaydet')),
        ],
      ),
    );
  }

  // --- PUAN KAZANMA TEST BUTONU (Sadece deneme amaçlı) ---
  void _addPoints(String uid) {
    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'points': FieldValue.increment(10) // Her basışta 10 puan ekler
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const Color darkGreen = Color(0xFF388E3C);
    const Color lightGreen = Color(0xFFDCEADD);

    return Scaffold(
      backgroundColor: lightGreen, 
      appBar: AppBar(
        title: const Text('Profilim'),
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          String name = "İsimsiz"; 
          String age = "0";
          String email = user?.email ?? "E-posta bulunamadı"; 
          int points = 0;

          if (snapshot.hasData && snapshot.data!.exists) { 
            var data = snapshot.data!.data() as Map<String, dynamic>?; 
            if (data != null) { 
              name = data['name'] ?? "İsimsiz"; 
              age = data['age']?.toString() ?? "0"; 
              points = data['points'] ?? 0; // Puanı veritabanından çek (yoksa 0)
            } 
          }

          String currentRank = _getRank(points);

          return SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                
                // --- PROFİL FOTOĞRAFI ---
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const CircleAvatar(radius: 55, backgroundColor: darkGreen, child: Icon(Icons.person, size: 60, color: Colors.white)),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.star, color: Colors.white, size: 20),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // --- İSİM VE DÜZENLE İKONU ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkGreen)),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: () { if (user != null) { _showEditProfileDialog(context, name, age, user.uid); } }, child: const Icon(Icons.edit, size: 20, color: darkGreen)),
                  ],
                ),
                const SizedBox(height: 5),
                Text('$age Yaşında | $email', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 20),

                // --- OYUNLAŞTIRMA (RÜTBE VE PUAN KARTI) ---
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                  child: Column(
                    children: [
                      Text(currentRank, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars, color: darkGreen, size: 28),
                          const SizedBox(width: 8),
                          Text('$points Puan', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      // Puan Kazanma Test Butonu
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF1F8E9), foregroundColor: darkGreen, elevation: 0),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Görevi Tamamla (+10 Puan)'),
                        onPressed: () { if (user != null) _addPoints(user.uid); },
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- LİDERLİK TABLOSU BUTONU ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: darkGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.leaderboard),
                      label: const Text('Liderlik Tablosunu Gör', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () => _showLeaderboard(context),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
// -------------------------------------------------------------------
// 🔍 KEŞFET SAYFASI (Arama Çubuğu, Çeviri, Yorumlar ve HIZLI KATEGORİLER)
// -------------------------------------------------------------------
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  List meals = []; 
  bool isLoading = true;
  final translator = GoogleTranslator();
  final TextEditingController _searchController = TextEditingController();

  // YENİ: Kategori Listesi (Türkçe görünüm, İngilizce arama)
  final List<Map<String, String>> _categories = [
    {'tr': 'Tümü', 'en': 'Random'},
    {'tr': 'Et', 'en': 'Beef'},
    {'tr': 'Tavuk', 'en': 'Chicken'},
    {'tr': 'Tatlı', 'en': 'Dessert'},
    {'tr': 'Makarna', 'en': 'Pasta'},
    {'tr': 'Deniz Ürünleri', 'en': 'Seafood'},
    {'tr': 'Vejetaryen', 'en': 'Vegetarian'},
    {'tr': 'Kahvaltı', 'en': 'Breakfast'},
  ];
  String _selectedCategory = 'Tümü'; // Varsayılan seçili kategori

  @override 
  void initState() { super.initState(); fetchMeals(); }

  // --- RASTGELE YEMEK ÇEKME VEYA KATEGORİYE GÖRE ÇEKME ---
  Future<void> fetchMeals({String? specificCategory}) async {
    if (!mounted) return; setState(() => isLoading = true);
    try {
      String searchCat;
      if (specificCategory == null || specificCategory == 'Random') {
        List<String> categories = ['Beef', 'Chicken', 'Dessert', 'Pasta', 'Seafood', 'Vegetarian', 'Breakfast']; 
        searchCat = categories[Random().nextInt(categories.length)];
      } else {
        searchCat = specificCategory;
      }

      final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/filter.php?c=$searchCat'));
      
      if (response.statusCode == 200 && mounted) { 
        List fetchedMeals = json.decode(response.body)['meals']; 
        fetchedMeals.shuffle(); 
        var selectedMeals = fetchedMeals.take(14).toList(); 

        String combinedTitles = selectedMeals.map((m) => m['strMeal']).join(' /// ');
        var trTitles = await translator.translate(combinedTitles, to: 'tr');
        var trTitleList = trTitles.text.split('///');

        for (int i = 0; i < selectedMeals.length; i++) {
          selectedMeals[i]['strMealTr'] = i < trTitleList.length ? trTitleList[i].trim() : selectedMeals[i]['strMeal'];
        }

        setState(() { meals = selectedMeals; isLoading = false; }); 
      }
    } catch (e) { 
      if (mounted) setState(() => isLoading = false); 
    }
  }

  // --- ARAMA MOTORU ---
  Future<void> _searchMeals(String query) async {
    if (query.trim().isEmpty) { fetchMeals(); return; }
    if (!mounted) return; setState(() { isLoading = true; _selectedCategory = ''; }); // Aramada kategori seçimini kaldır
    
    try {
      var translatedQuery = await translator.translate(query, to: 'en');
      String englishSearchTerm = translatedQuery.text;

      final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/search.php?s=$englishSearchTerm'));
      
      if (response.statusCode == 200 && mounted) {
        var decodedData = json.decode(response.body);
        List fetchedMeals = decodedData['meals'] ?? []; 
        
        if (fetchedMeals.isEmpty) { setState(() { meals = []; isLoading = false; }); return; }

        var selectedMeals = fetchedMeals.take(14).toList();
        String combinedTitles = selectedMeals.map((m) => m['strMeal']).join(' /// ');
        var trTitles = await translator.translate(combinedTitles, to: 'tr');
        var trTitleList = trTitles.text.split('///');

        for (int i = 0; i < selectedMeals.length; i++) {
          selectedMeals[i]['strMealTr'] = i < trTitleList.length ? trTitleList[i].trim() : selectedMeals[i]['strMeal'];
        }

        setState(() { meals = selectedMeals; isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- YORUM PENCERESİ ---
  void _showCommentsDialog(BuildContext context, String mealId, String mealName) {
    TextEditingController commentController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('$mealName Yorumları', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9, 
            height: MediaQuery.of(context).size.height * 0.5, 
            child: Column(
              children: [
                const Divider(),
                Expanded(
                  child: StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('recipe_comments').where('mealId', isEqualTo: mealId).snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
                      if (snapshot.hasError) return const Center(child: Text('Bir hata oluştu.', textAlign: TextAlign.center));
                      
                      var docs = snapshot.data?.docs.toList() ?? [];
                      docs.sort((a, b) {
                        var timeA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        var timeB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        if (timeA == null) return -1; 
                        if (timeB == null) return 1;
                        return timeB.compareTo(timeA); 
                      });

                      if (docs.isEmpty) return const Center(child: Text('Henüz yorum yok. İlk yorumu sen yap!', style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var doc = docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(backgroundColor: Color(0xFFDCEADD), child: Icon(Icons.person, color: Color(0xFF2E7D32))),
                            title: Text(doc['userName'] ?? 'Kullanıcı', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(doc['comment'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                          );
                        }
                      );
                    }
                  )
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          decoration: InputDecoration(
                            hintText: 'Yorumunu yaz...',
                            filled: true,
                            fillColor: const Color(0xFFF1F8E9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                          ),
                        )
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: () async {
                            if (commentController.text.trim().isNotEmpty && user != null) {
                              var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                              String userName = userDoc.exists ? (userDoc.data()?['name'] ?? 'İsimsiz') : 'İsimsiz';

                              await FirebaseFirestore.instance.collection('recipe_comments').add({
                                'mealId': mealId,
                                'uid': user.uid,
                                'userName': userName,
                                'comment': commentController.text.trim(),
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                              commentController.clear();
                            }
                          }
                        ),
                      )
                    ]
                  ),
                )
              ]
            )
          )
        );
      }
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keşfet'), 
        actions: [
          // YENİ EKLENEN TOPLULUK BUTONU 👇
          IconButton(
            icon: const Icon(Icons.people_alt_outlined), 
            tooltip: 'Topluluk Tarifleri',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityRecipesPage())),
          ),
          IconButton(
            icon: const Icon(Icons.refresh), 
            onPressed: () {
              _searchController.clear(); 
              setState(() => _selectedCategory = 'Tümü');
              fetchMeals();
            }
          )
        ]
      ),
      body: Column(
        children: [
          // --- ARAMA ÇUBUĞU BÖLÜMÜ ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onSubmitted: (value) => _searchMeals(value), 
              decoration: InputDecoration(
                hintText: 'Yemek veya malzeme ara...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _selectedCategory = 'Tümü');
                    fetchMeals(); 
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0)
              ),
            ),
          ),

          // --- YENİ: KATEGORİ CHIPS (FİLTRELER) BÖLÜMÜ ---
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                var category = _categories[index];
                bool isSelected = _selectedCategory == category['tr'];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category['tr']!, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2E7D32),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300)),
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category['tr']!);
                        _searchController.clear();
                        fetchMeals(specificCategory: category['en']);
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // --- YEMEK KARTLARI BÖLÜMÜ ---
          Expanded(
            child: isLoading 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))) 
              : meals.isEmpty 
                ? const Center(child: Text("Aradığın yemek bulunamadı 😔", style: TextStyle(color: Colors.grey, fontSize: 16)))
                : RefreshIndicator(
                    onRefresh: () async {
                      _searchController.clear();
                      setState(() => _selectedCategory = 'Tümü');
                      await fetchMeals();
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), 
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.70, crossAxisSpacing: 15, mainAxisSpacing: 15), 
                      itemCount: meals.length,
                      itemBuilder: (context, index) {
                        var meal = meals[index];
                        int displayCalorie = 200 + (meal['strMeal'].toString().length * 15) % 400;

                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailScreen(mealId: meal['idMeal']))),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3, 
                                  child: Stack(
                                    children: [
                                      ClipRRect(borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)), child: Image.network(meal['strMealThumb'], width: double.infinity, fit: BoxFit.cover)), 
                                      Positioned(
                                        bottom: 10, left: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                                              const SizedBox(width: 4),
                                              Text('$displayCalorie kcal', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8, right: 8, 
                                        child: IconButton(
                                          icon: const Icon(Icons.favorite_border, color: Colors.red, size: 20), 
                                          onPressed: () { 
                                            FirebaseFirestore.instance.collection('user_favorites').add({'mealId': meal['idMeal'], 'uid': FirebaseAuth.instance.currentUser?.uid, 'name': meal['strMealTr'] ?? meal['strMeal'], 'image': meal['strMealThumb'], 'timestamp': FieldValue.serverTimestamp()}); 
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Favorilere eklendi!'))); 
                                          }
                                        )
                                      )
                                    ]
                                  )
                                ),
                                Expanded(
                                  flex: 2, 
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0), 
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(meal['strMealTr'] ?? meal['strMeal'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        GestureDetector(
                                          onTap: () => _showCommentsDialog(context, meal['idMeal'], meal['strMealTr'] ?? meal['strMeal']),
                                          child: const Text("💬 Yorumları Gör", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                        )
                                      ],
                                    )
                                  )
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
// -------------------------------------------------------------------
// 📖 TARIF DETAY SAYFASI (Alışveriş Listesine Ekleme Özelliği Eklendi)
// -------------------------------------------------------------------
class RecipeDetailScreen extends StatefulWidget {
  final String mealId; const RecipeDetailScreen({super.key, required this.mealId});
  @override State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic>? recipeData; 
  String? translatedTitle;
  String? translatedInstructions;
  String? translatedCategory;
  String? translatedArea;
  List<String> translatedIngredients = [];
  bool isLoading = true;

  @override void initState() { super.initState(); fetchAndTranslateDetails(); }
  
  Future<void> fetchAndTranslateDetails() async { 
    try {
      final response = await http.get(Uri.parse('https://www.themealdb.com/api/json/v1/1/lookup.php?i=${widget.mealId}')); 
      if (mounted) {
        var data = json.decode(response.body)['meals'][0];
        final translator = GoogleTranslator();
        
        var titleTr = await translator.translate(data['strMeal'] ?? '', to: 'tr');
        var instructionsTr = await translator.translate(data['strInstructions'] ?? '', to: 'tr');
        var categoryTr = await translator.translate(data['strCategory'] ?? '', to: 'tr');
        var areaTr = await translator.translate(data['strArea'] ?? '', to: 'tr');

        List<String> rawIngredients = [];
        for (int i = 1; i <= 20; i++) {
          if (data['strIngredient$i'] != null && data['strIngredient$i'].toString().trim().isNotEmpty) {
            rawIngredients.add('${data['strMeasure$i']} ${data['strIngredient$i']}');
          }
        }

        String combinedIng = rawIngredients.join(' /// ');
        var trIng = await translator.translate(combinedIng, to: 'tr');
        List<String> tempIngredients = trIng.text.split('///').map((e) => e.trim()).toList();

        setState(() { 
          recipeData = data; 
          translatedTitle = titleTr.text;
          translatedInstructions = instructionsTr.text;
          translatedCategory = categoryTr.text;
          translatedArea = areaTr.text;
          translatedIngredients = tempIngredients;
          isLoading = false; 
        }); 
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- YENİ: Alışveriş Listesine Malzeme Ekleme Fonksiyonu ---
  void _addToShoppingList(String ingredient) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('user_shopping_list').add({
        'uid': user.uid,
        'name': ingredient,
        'isDone': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$ingredient" alışveriş listesine eklendi! 🛒'),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Color(0xFF2E7D32)), SizedBox(height: 15), Text('Tarif Türkçeye çevriliyor...', style: TextStyle(color: Colors.grey))])));
    if (recipeData == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Tarif bulunamadı.')));

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300, 
            pinned: true,
            backgroundColor: const Color(0xFF2E7D32),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(recipeData!['strMealThumb'], fit: BoxFit.cover),
            )
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(translatedTitle ?? '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  const SizedBox(height: 15),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                        child: Text(translatedCategory ?? '', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)),
                        child: Text(translatedArea ?? '', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  const Text("Malzemeler", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text("Eksikleri listene eklemek için yanındaki sepet ikonuna dokun.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  
                  // --- GÜNCELLENEN MALZEME LİSTESİ ---
                  ...translatedIngredients.map((ing) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(ing, style: const TextStyle(fontSize: 16, color: Colors.black87))),
                        // EKLEME BUTONU 👇
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart, color: Color(0xFF2E7D32), size: 20),
                          onPressed: () => _addToShoppingList(ing),
                        ),
                      ],
                    ),
                  )),
                  
                  const SizedBox(height: 30),
                  const Text("Hazırlanışı", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    translatedInstructions ?? '', 
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)
                  ),
                  const SizedBox(height: 50),
                ]
              ),
            ),
          )
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// ❤️ FAVORİLER SAYFASI (Tıklama Özelliği Eklendi)
// -------------------------------------------------------------------
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  
  @override 
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Favorilerim')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('user_favorites').where('uid', isEqualTo: user?.uid).orderBy('timestamp', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Bir hata oluştu veya indeks bekleniyor...'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
          
          var docs = snapshot.data!.docs;
          
          if (docs.isEmpty) {
            return const Center(child: Text("Henüz favori yemeğin yok ❤️", style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16), 
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(data['image'] ?? '', width: 60, height: 60, fit: BoxFit.cover),
                  ), 
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), 
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                    onPressed: () => FirebaseFirestore.instance.collection('user_favorites').doc(docs[index].id).delete()
                  ),
                  
                  // TIKLAMA ÖZELLİĞİ BURADA 👇
                  onTap: () {
                    // Eğer yemeğin ID'si veritabanında varsa detay sayfasına git
                    if (data.containsKey('mealId') && data['mealId'] != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailScreen(mealId: data['mealId'])));
                    } else {
                      // Eski eklenen favorilerde ID olmadığı için bu uyarıyı verecek
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu eski bir kayıt. Detayını görmek için Keşfet sayfasından tekrar favorileyin!')));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------------
// 🔐 GİRİŞ VE KAYIT EKRANLARI
// -------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(); final _pass = TextEditingController();
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD5E8D4),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco, size: 48, color: Colors.green), const Text('Kitchy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)), const SizedBox(height: 20),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder())), const SizedBox(height: 12),
                TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder())), const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () async { try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text, password: _pass.text); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen())); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hatalı giriş!'))); } }, child: const Text('Giriş Yap'))),
                TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())), child: const Text('Hesabın yok mu? Kayıt Ol')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController(); final _pass = TextEditingController(); final _name = TextEditingController(); final _age = TextEditingController();
  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD5E8D4), appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF2E7D32))),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco, size: 60, color: Color(0xFF4CAF50)), const Text('Kitchy\'ye Katıl', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))), const SizedBox(height: 30),
                _inputField(_name, 'Ad Soyad', Icons.person), const SizedBox(height: 15), _inputField(_age, 'Yaş', Icons.cake, type: TextInputType.number), const SizedBox(height: 15), _inputField(_email, 'E-posta', Icons.email), const SizedBox(height: 15), _inputField(_pass, 'Şifre', Icons.lock, obscure: true), const SizedBox(height: 30),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { try { UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text, password: _pass.text); await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({'name': _name.text, 'age': int.tryParse(_age.text) ?? 0, 'email': _email.text}); if (context.mounted) Navigator.pop(context); } catch (err) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıt başarısız!'))); } }, child: const Text('Kaydol', style: TextStyle(fontSize: 18)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _inputField(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType type = TextInputType.text}) { return TextField(controller: controller, obscureText: obscure, keyboardType: type, decoration: InputDecoration(prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)), labelText: label, filled: true, fillColor: const Color(0xFFF1F8E9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))); }
}


// 1. Uygulama Ayarları Ekranı
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uygulama Ayarları'),
        backgroundColor: const Color(0xFF2E7D32), // Profildeki yeşil tona uygun
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Karanlık Tema'),
            value: false, // Şimdilik varsayılan kapalı
            onChanged: (bool value) {},
            activeColor: const Color(0xFF2E7D32),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Bildirimler'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {}, // İleride doldurulabilir
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Dil Seçeneği'),
            subtitle: const Text('Türkçe'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// 2. Yardım & Destek Ekranı
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yardım & Destek'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const ListTile(
            leading: Icon(Icons.email),
            title: Text('Bize Ulaşın'),
            subtitle: Text('destek@kitchy.com'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.question_answer),
            title: const Text('Sıkça Sorulan Sorular'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// 3. Hakkımızda Ekranı
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hakkımızda'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 80, color: Color(0xFF2E7D32)), // Uygulamanın logosu/ikonu
            SizedBox(height: 16),
            Text(
              'Kitchy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Versiyon 1.0.0', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 24),
            Text(
              'Kitchy, mutfaktaki en iyi yardımcınız olmak için tasarlandı. Lezzetli tarifler, planlamalar ve daha fazlası burada!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
// -------------------------------------------------------------------
// 🛒 AKILLI ALIŞVERİŞ LİSTESİ SAYFASI (İndeks Hatası Çözüldü)
// -------------------------------------------------------------------
class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final TextEditingController _itemController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  void _addItem() async {
    if (_itemController.text.trim().isNotEmpty && user != null) {
      await FirebaseFirestore.instance.collection('user_shopping_list').add({
        'uid': user!.uid,
        'name': _itemController.text.trim(),
        'isDone': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _itemController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alışveriş Listesi')),
      body: Column(
        children: [
          // --- Malzeme Ekleme Alanı ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: InputDecoration(
                      hintText: 'Eksik malzemeyi yaz...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  mini: true,
                  backgroundColor: const Color(0xFF2E7D32),
                  onPressed: _addItem,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // --- Alışveriş Listesi Alanı ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // İndeks hatasını önlemek için orderBy buradan kaldırıldı
              stream: FirebaseFirestore.instance
                  .collection('user_shopping_list')
                  .where('uid', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                // Yüklenme durumu
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
                }
                
                if (snapshot.hasError) {
                  return const Center(child: Text('Bir hata oluştu.', textAlign: TextAlign.center, style: TextStyle(color: Colors.red)));
                }
                
                var docs = snapshot.data?.docs.toList() ?? [];
                
                // Sıralamayı Firebase yerine kodun içinde (Dart ile) yapıyoruz
                docs.sort((a, b) {
                  var timeA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  var timeB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  if (timeA == null) return -1; // Yeni eklenen anında üste çıkar
                  if (timeB == null) return 1;
                  return timeB.compareTo(timeA); // Yeniden eskiye sıralama
                });

                if (docs.isEmpty) {
                  return const Center(child: Text("Listeniz boş 🛒", style: TextStyle(color: Colors.grey, fontSize: 16)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isDone = data['isDone'] ?? false;
                    String docId = docs[index].id;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: Checkbox(
                          activeColor: const Color(0xFF2E7D32),
                          value: isDone,
                          onChanged: (val) {
                            // Kutucuk işaretlendiğinde veritabanını güncelle
                            FirebaseFirestore.instance
                                .collection('user_shopping_list')
                                .doc(docId)
                                .update({'isDone': val});
                          },
                        ),
                        title: Text(
                          data['name'] ?? '',
                          style: TextStyle(
                            decoration: isDone ? TextDecoration.lineThrough : null, // İşaretliyse üstünü çiz
                            color: isDone ? Colors.grey : Colors.black87,
                            fontWeight: isDone ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => FirebaseFirestore.instance
                              .collection('user_shopping_list')
                              .doc(docId)
                              .delete(), // Çöp kutusuna basıldığında sil
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
// -------------------------------------------------------------------
// 🌍 TOPLULUK TARİFLERİ SAYFASI (Silme Özelliği + ImgBB Resim Yükleme)
// -------------------------------------------------------------------
class CommunityRecipesPage extends StatelessWidget {
  const CommunityRecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Topluluk Tarifleri')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('community_recipes').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
          if (snapshot.hasError) return const Center(child: Text('Veriler yüklenemedi.', style: TextStyle(color: Colors.red)));

          var docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text("Henüz tarif yok. İlk sen paylaş! 👩‍🍳", style: TextStyle(color: Colors.grey, fontSize: 16)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id; // Silme işlemi için ID'yi alıyoruz
              String? mealImageUrl = data['mealImageUrl']; 
              bool isMine = currentUser?.uid == data['uid']; // Tarifin sahibi biz miyiz kontrolü

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ExpansionTile(
                  iconColor: const Color(0xFF2E7D32),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: mealImageUrl != null 
                        ? Image.network(mealImageUrl, width: 50, height: 50, fit: BoxFit.cover)
                        : const CircleAvatar(backgroundColor: Color(0xFFDCEADD), child: Icon(Icons.restaurant_menu, color: Color(0xFF2E7D32))),
                  ),
                  title: Text(data['mealName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text("Şef: ${data['authorName']}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (mealImageUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 15.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(mealImageUrl, width: double.infinity, height: 150, fit: BoxFit.cover),
                              ),
                            ),
                          const Text("Malzemeler:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                          const SizedBox(height: 4),
                          Text(data['ingredients'] ?? ''),
                          const Divider(height: 20),
                          const Text("Hazırlanışı:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                          const SizedBox(height: 4),
                          Text(data['instructions'] ?? ''),

                          // --- SİLME BUTONU (Sadece Kullanıcının Kendi Tarifinde Çıkar) ---
                          if (isMine) ...[
                            const Divider(height: 30),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  // Firebase'den siliyoruz
                                  FirebaseFirestore.instance.collection('community_recipes').doc(docId).delete();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content: Text('Tarifin başarıyla silindi! 🗑️'), backgroundColor: Colors.redAccent, duration: Duration(seconds: 2)
                                  ));
                                },
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                label: const Text('Tarifimi Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ]
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        onPressed: () {
          showDialog(context: context, builder: (context) => const AddRecipeDialogWidget());
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Tarif Ekle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- YENİ: TARİF EKLEME PENCERESİ (Web Uyumlu & ImgBB API BAĞLANTILI) ---
class AddRecipeDialogWidget extends StatefulWidget {
  const AddRecipeDialogWidget({super.key});
  @override State<AddRecipeDialogWidget> createState() => _AddRecipeDialogWidgetState();
}

class _AddRecipeDialogWidgetState extends State<AddRecipeDialogWidget> {
  TextEditingController nameController = TextEditingController();
  TextEditingController ingredientsController = TextEditingController();
  TextEditingController instructionsController = TextEditingController();
  
  Uint8List? _imageBytes; // WEB UYUMLU: File yerine Uint8List kullanıyoruz
  final picker = ImagePicker();
  bool _isUploading = false; 

  // --- Web Uyumlu Resim Seçme ---
  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70); 
    if (pickedFile != null) {
      var bytes = await pickedFile.readAsBytes(); 
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  // --- Web Uyumlu ImgBB Yükleme ---
  Future<String?> _uploadImageToImgBB(Uint8List imageBytes) async {
    try {
      // ŞİFREN BURAYA EKLENDİ!
      const String imgbbApiKey = 'c69a1cb6062a6e9f1157ff21af1b5aa4'; 
      
      var request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload'));
      request.fields['key'] = imgbbApiKey;
      request.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: 'recipe_image.jpg'));
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var result = json.decode(responseData);
      
      if (result['success']) {
        return result['data']['url']; 
      }
      return null;
    } catch (e) {
      debugPrint('Resim yükleme hatası: $e');
      return null;
    }
  }

  @override Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.restaurant, color: Color(0xFF2E7D32)), SizedBox(width: 8), Text('Kendi Tarifini Ekle', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 16))]),
      
      content: _isUploading 
        ? const SizedBox(height: 150, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Color(0xFF2E7D32)), SizedBox(height: 15), Text('Tarif paylaşılıyor...', style: TextStyle(color: Colors.grey)) ]))) 
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(color: const Color(0xFFDCEADD), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                    child: _imageBytes != null 
                        ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.memory(_imageBytes!, fit: BoxFit.cover)) 
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Color(0xFF2E7D32)), SizedBox(height: 8), Text('Fotoğraf Ekle', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12))]),
                  ),
                ),
                TextField(controller: nameController, decoration: InputDecoration(labelText: 'Yemeğin Adı', filled: true, fillColor: const Color(0xFFF1F8E9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                const SizedBox(height: 10),
                TextField(controller: ingredientsController, maxLines: 2, decoration: InputDecoration(labelText: 'Malzemeler (Virgülle ayır)', filled: true, fillColor: const Color(0xFFF1F8E9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
                const SizedBox(height: 10),
                TextField(controller: instructionsController, maxLines: 4, decoration: InputDecoration(labelText: 'Hazırlanışı', filled: true, fillColor: const Color(0xFFF1F8E9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
              ],
            ),
          ),
      actions: [
        if (!_isUploading) TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
        
        if (!_isUploading) ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            if (nameController.text.trim().isNotEmpty && user != null) {
              
              setState(() => _isUploading = true); 

              String? imageUrl;
              if (_imageBytes != null) {
                imageUrl = await _uploadImageToImgBB(_imageBytes!); 
              }

              var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
              String userName = userDoc.exists ? (userDoc.data()?['name'] ?? 'İsimsiz Şef') : 'İsimsiz Şef';

              await FirebaseFirestore.instance.collection('community_recipes').add({
                'uid': user.uid,
                'authorName': userName,
                'mealName': nameController.text.trim(),
                'ingredients': ingredientsController.text.trim(),
                'instructions': instructionsController.text.trim(),
                'mealImageUrl': imageUrl, 
                'timestamp': FieldValue.serverTimestamp(),
              });

              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Paylaş'),
        )
      ],
    );
  }
}