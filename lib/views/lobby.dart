import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mafioso/cubits/auth_state.dart';
import '../cubits/game_cubit.dart';
import '../models/game_room.dart';
import '../models/player.dart';
import 'game_screen.dart';
import 'main_menu.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cubits/auth_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _selectedDiscussionDuration = 300;
  int _selectedCaseIndex = 0;
  List<Map<String, dynamic>> _cases = [];
  bool _loadingCases = true;
  bool _settingsConfirmed = false;
  bool _nameDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _fetchCasesFromDB();
  }

  Future<void> _fetchCasesFromDB() async {
    try {
      setState(() => _loadingCases = true);
      final ref = FirebaseDatabase.instance.ref().child('cases');
      final snap = await ref.get();

      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        _cases = data.values.map((caseData) {
          final caseMap = Map<String, dynamic>.from(caseData as Map);
          
          // Explicitly convert hints to List<String>
          if (caseMap.containsKey('hints') && caseMap['hints'] != null) {
            caseMap['hints'] = List<String>.from(caseMap['hints'].map((item) => item.toString()));
          } else {
            caseMap['hints'] = <String>[];
          }

          // Explicitly convert suspects to List<Map<String, dynamic>>
          if (caseMap.containsKey('suspects') && caseMap['suspects'] != null) {
            final suspectsList = List<dynamic>.from(caseMap['suspects']);
            caseMap['suspects'] = suspectsList.map((suspect) {
              return Map<String, dynamic>.from(suspect as Map);
            }).toList();
          } else {
            caseMap['suspects'] = <Map<String, dynamic>>[];
          }

          return caseMap;
        }).toList();
      } else {
        // This part can be removed if you are managing cases from the admin panel
        // and don't need to pre-populate them from the app.
        // For now, let's keep it as a fallback.
        await _initializeCases();
        // Fetch again after initialization
        await _fetchCasesFromDB(); 
      }
    } catch (e) {
      debugPrint('Error fetching cases: $e');
      // Optionally show an error to the user
    } finally {
      if (mounted) {
        setState(() => _loadingCases = false);
      }
    }
  }

  Future<void> _initializeCases() async {
    try {
      final cases = [
        {
          'title': 'جريمة في الفيلا',
          'description': 'في فيلا فاخرة على أطراف المدينة، تم العثور على جثة رجل أعمال مشهور مقتولاً في مكتبه. التحقيق يكشف عن شبكة معقدة من العلاقات والعداوات بين الحاضرين في الحفل الذي أقيم في الليلة السابقة.',
          'hints': [
            'تم العثور على آثار دماء على مقبض الباب',
            'شاهد أحد الخدم شخصاً يغادر المكتب في وقت متأخر',
            'كان الضحية يتلقى تهديدات قبل وفاته',
            'تم العثور على رسالة غامضة في جيبه',
          ],
          'confession': 'كنت أعرف الضحية منذ سنوات. كان يهددني بكشف أسرار عائلتي. في تلك الليلة، ذهبت إلى مكتبه لنتحدث، لكنه رفض الاستماع. شعرت بالغضب والخوف، فأمسكت بالمصباح الثقيل وضربته. لم أكن أقصد قتله، لكن الأمر حدث بسرعة. الآن أعترف بكل شيء وأطلب الرحمة.',
        },
        {
          'title': 'لغز القطار',
          'description': 'في رحلة قطار ليلية، تم العثور على مسافر مقتول في مقصورته الخاصة. جميع الركاب في نفس العربة مشتبه بهم، وكل منهم لديه دافع وفرصة للقتل.',
          'hints': [
            'الضحية كان يحمل حقيبة مليئة بالمال',
            'سمع أحد الركاب أصوات شجار قبل منتصف الليل',
            'كان هناك توقف غير متوقع للقطار',
            'تم العثور على مفتاح غريب في المقصورة',
          ],
          'confession': 'كنت أعمل مع الضحية في صفقة تجارية كبيرة. اكتشفت أنه كان يخطط لخداعي وسرقة حصتي. في تلك الليلة، ذهبت إلى مقصورته لمواجهته. عندما رفض الاعتراف، شعرت بالخيانة والغضب. أمسكت بالسكين التي كانت على الطاولة وطعنته. الآن أعترف بجريمتي وأتحمل عواقبها.',
        },
        {
          'title': 'سر المطعم',
          'description': 'في مطعم شهير في وسط المدينة، تم العثور على طاهي مقتول في المطبخ بعد إغلاق المطعم. التحقيق يكشف عن منافسات شرسة وعلاقات معقدة بين العاملين.',
          'hints': [
            'الضحية كان يخطط لفتح مطعم منافس',
            'تم العثور على رسائل تهديد في هاتفه',
            'كان هناك شجار بين الطهاة في اليوم السابق',
            'أحد العاملين اختفى بعد الحادثة',
          ],
          'confession': 'كنت شريك الضحية في المطعم. عندما أخبرني أنه يريد فتح مطعم منافس وسحب استثماراته، شعرت بالخوف على مستقبلي. في تلك الليلة، ذهبت إلى المطبخ لنتحدث، لكنه رفض التراجع عن قراره. أمسكت بسكين المطبخ وطعنته. الآن أعترف بجريمتي وأطلب العفو.',
        },
      ];

      final ref = FirebaseDatabase.instance.ref().child('cases');
      for (int i = 0; i < cases.length; i++) {
        await ref.child('case_$i').set(cases[i]);
      }
    } catch (e) {
      debugPrint('Error initializing cases: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameCubit, GameState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        if (_loadingCases) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        }
        if (state is GameRoomLoaded) {
          return _buildLobbyContent(context, state);
        }
        return _buildLoadingState(state);
      },
    );
  }

  void _handleStateChanges(BuildContext context, GameState state) {
    if (state is GameRoomLoaded) {
      final currentPlayer = state.currentPlayer;
      final room = state.room;

      if (currentPlayer == null && !_nameDialogOpen) {
        _nameDialogOpen = true;
        Future.microtask(() => _showPlayerNameDialog(context, room));
      }

      if (state.room.status == 'playing') {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route is PageRoute);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    }
  }

  Widget _buildLobbyContent(BuildContext context, GameRoomLoaded state) {
    final room = state.room;
    final currentPlayer = state.currentPlayer;
    final isHost = currentPlayer != null && room.hostId == currentPlayer.id;
    if (currentPlayer == null) {
      // اللاعب لم يدخل اسمه بعد أو لم يتم تعيينه بعد
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('اللوبي'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple[800]!, Colors.deepPurple[600]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
                Color(0xFF0F3460),
              ],
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('اللوبي', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple[800]!, Colors.deepPurple[600]!],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          if (_settingsConfirmed && isHost)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cancel, color: Colors.white),
                label: const Text('إلغاء الغرفة', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () async {
                  await FirebaseDatabase.instance.ref().child('rooms').child(room.id).remove();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isHost && !_settingsConfirmed) _buildHostSettings(room),
                if (_settingsConfirmed) _buildRoomInfoSection(room, isHost),
                if (!isHost || _settingsConfirmed) _buildPlayersList(room),
                if (isHost && _settingsConfirmed && room.players.length < 8)
                   _buildAddDummyPlayerButton(),
                if (_settingsConfirmed && isHost && room.players.length >= 2)
                  _buildStartGameButton(room),
                if (_settingsConfirmed && isHost)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text('إلغاء الغرفة', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        textStyle: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () async {
                        await FirebaseDatabase.instance.ref().child('rooms').child(room.id).remove();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHostSettings(GameRoom room) {
    return Column(
      children: [
        _buildCaseSelectionButton(),
        _buildDurationSelectionRow(),
        SizedBox(height: 20.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                // حذف الغرفة من Firebase
                await FirebaseDatabase.instance.ref().child('rooms').child(room.id).remove();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainMenuScreen()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('إلغاء'),
            ),
            SizedBox(width: 16.w),
            _buildConfirmSettingsButton(room),
          ],
        ),
      ],
    );
  }

  Widget _buildCaseSelectionButton() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber[700]!,
            Colors.orange[600]!,
            Colors.deepOrange[500]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _cases.isEmpty ? null : () => _showCasePickerDialog(context),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 24.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.menu_book,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cases.isEmpty ? 'تحميل القصص...' : 'اختيار القصة',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _cases.isEmpty
                            ? 'يرجى الانتظار...'
                            : (_cases[_selectedCaseIndex]['title'] ?? 'اختر قصة مثيرة'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!_cases.isEmpty)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 200.ms)
      .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 200.ms);
  }

  Widget _buildDurationSelectionRow() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple[800]!.withOpacity(0.9),
            Colors.deepPurple[600]!.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurple[300]!.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer,
                color: Colors.amber[300],
                size: 24,
              ),
              SizedBox(width: 8.w),
              Text(
                'مدة النقاش',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final entry in [
                {'label': '2 دقائق', 'value': 120, 'icon': Icons.speed},
                {'label': '4 دقائق', 'value': 240, 'icon': Icons.timer},
                {'label': '6 دقائق', 'value': 360, 'icon': Icons.hourglass_empty},
              ])
                _buildDurationChip(
                  label: entry['label'] as String,
                  value: entry['value'] as int,
                  icon: entry['icon'] as IconData,
                  isSelected: _selectedDiscussionDuration == entry['value'],
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedDiscussionDuration = entry['value'] as int;
                      });
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 400.ms)
      .slideY(begin: 0.3, end: 0, duration: 600.ms, delay: 400.ms);
  }

  Widget _buildDurationChip({
    required String label,
    required int value,
    required IconData icon,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  Colors.amber[600]!,
                  Colors.orange[500]!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onSelected(true),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.amber[300]!
                    : Colors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.amber[300],
                  size: 20,
                ),
                SizedBox(height: 4.h),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
      .scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1, 1),
        duration: 300.ms,
        curve: Curves.elasticOut,
      );
  }

  Widget _buildConfirmSettingsButton(GameRoom room) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          textStyle: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo'),
        ),
        onPressed: _cases.isEmpty ? null : () {
          _confirmSettings(room);
        },
        child: const Text('انتقال'),
      ),
    );
  }

  Future<void> _confirmSettings(GameRoom room) async {
    try {
      final selectedCase = _cases[_selectedCaseIndex];
      await FirebaseDatabase.instance.ref().child('rooms').child(room.id).update({
        'discussionDuration': _selectedDiscussionDuration,
        'caseTitle': selectedCase['title'],
        'caseDescription': selectedCase['description'],
        'clues': List<String>.from(selectedCase['clues'] ?? []),
        'confession': selectedCase['confession'] ?? '',
      });
      setState(() => _settingsConfirmed = true);
    } catch (e) {
      debugPrint('Error confirming settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في حفظ الإعدادات')));
    }
  }

  Widget _buildRoomInfoSection(GameRoom room, bool isHost) {
    return Column(
      children: [
        Card(
          color: Colors.deepPurple.withOpacity(0.9),
          margin: EdgeInsets.all(24.h),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'رمز الغرفة',
                  style: TextStyle(
                      fontSize: 18.sp,
                      color: Colors.white,
                      fontFamily: 'Cairo'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      room.id,
                      style: TextStyle(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Cairo'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white),
                      onPressed: () => _copyToClipboard(room.id),
                    ),
                  ],
                ),
                if (isHost) ...[
                  SizedBox(height: 16.h),
                  Text(
                    'الرقم السري للغرفة (PIN) - أعطه لمن يريد الدخول:',
                    style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontFamily: 'Cairo'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        room.pin,
                        style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                            fontFamily: 'Cairo'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.amber),
                        onPressed: () => _copyToClipboard(room.pin),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildPlayersList(GameRoom room) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اللاعبون',
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 16.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380.w, // Max width for each item
              mainAxisSpacing: 10.h,
              crossAxisSpacing: 10.h,
              childAspectRatio: 4.8, // Adjust this ratio as needed
            ),
            itemCount: room.players.length,
            itemBuilder: (context, index) {
              final player = room.players[index];
              final isHost = player.id == room.hostId;
              return Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isHost ? Colors.amber : Colors.deepPurple, width: 2),
                ),
                child: Center(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isHost ? Colors.amber[300] : Colors.deepPurple[300],
                      child: Text(
                        player.avatar.isNotEmpty ? player.avatar : '?',
                        style: TextStyle(fontSize: 24.sp, color: Colors.white),
                      ),
                    ),
                    title: Text(
                      player.name,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    trailing: isHost
                        ? const Icon(Icons.admin_panel_settings, color: Colors.amber)
                        : null,
                  ),
                ),
              ).animate(delay: (100 * index).ms).fadeIn(duration: 500.ms).slideX(begin: -0.2);
            },
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildAddDummyPlayerButton() {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () {
          context.read<GameCubit>().addDummyPlayers(1);
        },
        child: const Text('إضافة لاعب وهمي'),
      ),
    );
  }

  Widget _buildStartGameButton(GameRoom room) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('ابدأ اللعبة'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_cases.isNotEmpty) {
            context.read<GameCubit>().startGame(
              discussionDuration: _selectedDiscussionDuration,
              selectedCase: _cases[_selectedCaseIndex],
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('لا توجد قصص متاحة لبدء اللعبة.')),
            );
          }
        },
      ),
    );
  }

  Widget _buildLoadingState(GameState state) {
    if (state is GameError) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF16213E),
                Color(0xFF0F3460),
              ],
            ),
          ),
          child: Center(
            child: Text(
              state.message,
              style: TextStyle(color: Colors.white, fontSize: 18.sp),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ الرمز: $text'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showPlayerNameDialog(BuildContext context, GameRoom room) async {
    // Get the current user's name from auth cubit
    final authState = context.read<AuthCubit>().state;
    String playerName = 'لاعب';
    
    if (authState is AuthSuccess) {
      playerName = authState.user.displayName ?? authState.user.email?.split('@')[0] ?? 'لاعب';
    }

    if (mounted) {
      _nameDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.blueGrey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.deepPurple[300]!, width: 2),
            ),
            title: Text(
              'تأكيد الانضمام',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'سيتم الانضمام للغرفة باسم:',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 8.h),
                Text(
                  playerName,
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () {
                  _registerPlayer(room, playerName);
                  Navigator.pop(context);
                },
                child: Text(
                  'انضمام',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ).then((_) {
        _nameDialogOpen = false;
      });
    }
  }

  Future<void> _registerPlayer(GameRoom room, String playerName) async {
    try {
      final playerId = DateTime.now().millisecondsSinceEpoch.toString();
      final newPlayer = Player(
        id: playerId,
        name: playerName,
        role: room.players.isEmpty ? 'مضيف' : 'مدني',
        avatar: '👤',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mafioso_player_id', playerId);

      final updatedPlayers = List<Player>.from(room.players)..add(newPlayer);
      await FirebaseDatabase.instance.ref()
          .child('rooms').child(room.id)
          .child('players')
          .set(updatedPlayers.map((p) => p.toJson()).toList());

      if (room.players.isEmpty) {
        await FirebaseDatabase.instance.ref()
            .child('rooms').child(room.id)
            .update({'hostId': playerId});
      }
    } catch (e) {
      debugPrint('Error registering player: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حدث خطأ في تسجيل اللاعب')));
      }
    }
  }

  void _showCasePickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.blueGrey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.deepPurple[300]!, width: 2),
          ),
          title: Text(
            'اختر قضية',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _cases.length,
              itemBuilder: (context, index) {
                final caseItem = _cases[index];
                return ListTile(
                  leading: Icon(Icons.book, color: Colors.amber[600]),
                  title: Text(
                    caseItem['title'] ?? 'قضية بدون عنوان',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedCaseIndex = index;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }
}