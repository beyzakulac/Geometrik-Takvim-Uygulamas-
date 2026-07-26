import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

void main() {
  runApp(const NoteCalendarApp());
}

// 1. DAHA ESTETİK VE YUMUŞAK RENK GEÇİŞLERİ
List<Color> getMonthColorsHelper(String monthName, bool isPassed) {
  List<Color> baseColors;

  if (['ARALIK', 'OCAK', 'ŞUBAT'].contains(monthName)) {
    // Kış: Buz mavisinden derin maviye
    baseColors = [const Color(0xFFB3E5FC), const Color(0xFF0288D1)];
  } else if (['MART', 'NİSAN', 'MAYIS'].contains(monthName)) {
    // İlkbahar: Açık yeşilden orman yeşiline
    baseColors = [const Color(0xFFC8E6C9), const Color(0xFF388E3C)];
  } else if (['HAZİRAN', 'TEMMUZ', 'AĞUSTOS'].contains(monthName)) {
    // Yaz: Şeftali tonundan sıcak kiremit/kırmızıya
    baseColors = [const Color(0xFFFFCCBC), const Color(0xFFD84315)];
  } else {
    // Sonbahar: Sıcak sarıdan koyu turuncuya
    baseColors = [const Color(0xFFFFE082), const Color(0xFFF57F17)];
  }

  if (isPassed) {
    // Geçmiş aylar için renkleri daha dengeli bir şekilde soluklaştır
    return baseColors.map((c) => Color.lerp(c, Colors.white, 0.65)!).toList();
  }
  return baseColors;
}

class MonthData {
  final String name;
  final int monthIndex;
  final double angle;
  final bool isLeft;
  final int yIndex;

  MonthData({
    required this.name,
    required this.monthIndex,
    required this.angle,
    required this.isLeft,
    required this.yIndex,
  });
}

class NoteCalendarApp extends StatelessWidget {
  const NoteCalendarApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Geometrik Takvim Notları',
      theme: ThemeData(primarySwatch: Colors.blueGrey),
      home: const CalendarHomeScreen(),
    );
  }
}

// 2. DAILY NOTE MODELİNE ÖNEMLİ (isImportant) ÖZELLİĞİ EKLENDİ
class DailyNote {
  final String id;
  final DateTime date;
  final String noteContent;
  final DateTime createdAt;
  final bool isImportant;

  DailyNote({
    String? id,
    required this.date,
    required this.noteContent,
    DateTime? createdAt,
    this.isImportant = false,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now();

  DailyNote copyWith({
    DateTime? date,
    String? noteContent,
    DateTime? createdAt,
    bool? isImportant,
  }) {
    return DailyNote(
      id: id,
      date: date ?? this.date,
      noteContent: noteContent ?? this.noteContent,
      createdAt: createdAt ?? this.createdAt,
      isImportant: isImportant ?? this.isImportant,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'noteContent': noteContent,
    'createdAt': createdAt.toIso8601String(),
    'isImportant': isImportant,
  };

  factory DailyNote.fromJson(Map<String, dynamic> json) => DailyNote(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    noteContent: json['noteContent'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    // Eski kaydedilmiş verilerde hata almamak için varsayılan değer false
    isImportant: json['isImportant'] as bool? ?? false,
  );
}

class NoteStorageService {
  static const String _storageKey = 'daily_notes';

  static Future<List<DailyNote>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? rawList = prefs.getStringList(_storageKey);
    if (rawList == null) return [];
    return rawList.map((raw) => DailyNote.fromJson(jsonDecode(raw))).toList();
  }

  static Future<void> saveNotes(List<DailyNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = notes
        .map((note) => jsonEncode(note.toJson()))
        .toList();
    await prefs.setStringList(_storageKey, rawList);
  }
}

class CalendarHomeScreen extends StatefulWidget {
  const CalendarHomeScreen({Key? key}) : super(key: key);

  @override
  State<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends State<CalendarHomeScreen> {
  List<DailyNote> _allNotes = [];
  bool _isLoading = true;

  static final List<DailyNote> _seedNotes = [
    DailyNote(
      id: 'seed-1',
      date: DateTime(2026, 7, 16),
      noteContent: "Flutter proje iskeleti tamamlanacak.",
      isImportant: true, // Örnek olarak bir önemli not eklendi
    ),
    DailyNote(
      id: 'seed-2',
      date: DateTime(2026, 7, 18),
      noteContent: "Veritabanı tasarımı yapılacak.",
    ),
    DailyNote(
      id: 'seed-3',
      date: DateTime(2026, 5, 10),
      noteContent: "Makine öğrenmesi modeli test edildi.",
    ),
    DailyNote(
      id: 'seed-4',
      date: DateTime(2026, 10, 5),
      noteContent: "Sonbahar dönemi başlangıcı.",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final storedNotes = await NoteStorageService.loadNotes();
    if (storedNotes.isEmpty) {
      _allNotes = List.from(_seedNotes);
      await NoteStorageService.saveNotes(_allNotes);
    } else {
      _allNotes = storedNotes;
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _persistNotes() async {
    await NoteStorageService.saveNotes(_allNotes);
  }

  final List<MonthData> _monthDataList = [
    MonthData(
      name: 'MAYIS',
      monthIndex: 5,
      angle: -105.0,
      isLeft: true,
      yIndex: 0,
    ),
    MonthData(
      name: 'NİSAN',
      monthIndex: 4,
      angle: -135.0,
      isLeft: true,
      yIndex: 1,
    ),
    MonthData(
      name: 'MART',
      monthIndex: 3,
      angle: -165.0,
      isLeft: true,
      yIndex: 2,
    ),
    MonthData(
      name: 'ŞUBAT',
      monthIndex: 2,
      angle: 165.0,
      isLeft: true,
      yIndex: 3,
    ),
    MonthData(
      name: 'OCAK',
      monthIndex: 1,
      angle: 135.0,
      isLeft: true,
      yIndex: 4,
    ),
    MonthData(
      name: 'ARALIK',
      monthIndex: 12,
      angle: 105.0,
      isLeft: true,
      yIndex: 5,
    ),
    MonthData(
      name: 'HAZİRAN',
      monthIndex: 6,
      angle: -75.0,
      isLeft: false,
      yIndex: 0,
    ),
    MonthData(
      name: 'TEMMUZ',
      monthIndex: 7,
      angle: -45.0,
      isLeft: false,
      yIndex: 1,
    ),
    MonthData(
      name: 'AĞUSTOS',
      monthIndex: 8,
      angle: -15.0,
      isLeft: false,
      yIndex: 2,
    ),
    MonthData(
      name: 'EYLÜL',
      monthIndex: 9,
      angle: 15.0,
      isLeft: false,
      yIndex: 3,
    ),
    MonthData(
      name: 'EKİM',
      monthIndex: 10,
      angle: 45.0,
      isLeft: false,
      yIndex: 4,
    ),
    MonthData(
      name: 'KASIM',
      monthIndex: 11,
      angle: 75.0,
      isLeft: false,
      yIndex: 5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double w = constraints.maxWidth;
              double h = math.max(constraints.maxHeight, 500.0);

              double cardHeight = 118.0;
              double cardGap = 2.0;
              double outerPadding = 10.0;
              double cardOffset = 150.0;

              double cardWidth = math.max(
                120.0,
                w / 2 - cardOffset - outerPadding,
              );

              double totalColumnHeight = (cardHeight * 6) + (cardGap * 5);
              double startYOffset = (h - totalColumnHeight) / 2;
              double slotHeight = cardHeight + cardGap;

              return SizedBox(
                width: w,
                height: h,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: CalendarConnectionPainter(
                          allNotes: _allNotes,
                          monthDataList: _monthDataList,
                          slotHeight: slotHeight,
                          startYOffset: startYOffset,
                          cardOffset: cardOffset,
                          cardHeight: cardHeight,
                        ),
                      ),
                    ),
                    ..._monthDataList.map((data) {
                      bool isPassed = data.monthIndex < DateTime.now().month;
                      double centerY =
                          startYOffset +
                          (data.yIndex * slotHeight) +
                          (slotHeight / 2);
                      double topPos = centerY - (cardHeight / 2);

                      final monthNotes =
                          _allNotes
                              .where((n) => n.date.month == data.monthIndex)
                              .toList()
                            ..sort((a, b) => a.date.day.compareTo(b.date.day));

                      return Positioned(
                        top: topPos,
                        left: data.isLeft ? outerPadding : null,
                        right: !data.isLeft ? outerPadding : null,
                        width: cardWidth,
                        height: cardHeight,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MonthDetailScreen(
                                  monthName: data.name,
                                  monthIndex: data.monthIndex,
                                  notes: _allNotes
                                      .where(
                                        (n) => n.date.month == data.monthIndex,
                                      )
                                      .toList(),
                                  onNoteAdded: (note) {
                                    setState(() {
                                      _allNotes.add(note);
                                    });
                                    _persistNotes();
                                  },
                                  onNoteUpdated: (updatedNote) {
                                    setState(() {
                                      final index = _allNotes.indexWhere(
                                        (n) => n.id == updatedNote.id,
                                      );
                                      if (index != -1) {
                                        _allNotes[index] = updatedNote;
                                      }
                                    });
                                    _persistNotes();
                                  },
                                  onNoteDeleted: (note) {
                                    setState(() {
                                      _allNotes.removeWhere(
                                        (n) => n.id == note.id,
                                      );
                                    });
                                    _persistNotes();
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            alignment: data.isLeft
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: getMonthColorsHelper(
                                  data.name,
                                  isPassed,
                                ),
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 6.0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: data.isLeft
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    data.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isPassed
                                          ? Colors.black54
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Expanded(
                                    child: monthNotes.isEmpty
                                        ? const SizedBox.shrink()
                                        : ListView.builder(
                                            padding: EdgeInsets.zero,
                                            itemCount: monthNotes.length,
                                            itemBuilder: (context, idx) {
                                              final note = monthNotes[idx];

                                              // 3. ANA EKRANDA ÖNEMLİ NOTLARI KOYU VE KALIN GÖSTERME
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  if (note.isImportant)
                                                    Icon(
                                                      Icons.star,
                                                      size: 10,
                                                      color: isPassed
                                                          ? Colors.black54
                                                          : Colors.black87,
                                                    ),
                                                  if (note.isImportant)
                                                    const SizedBox(width: 2),
                                                  Expanded(
                                                    child: Text(
                                                      '${note.date.day}: ${note.noteContent}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            note.isImportant
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                        color: isPassed
                                                            ? (note.isImportant
                                                                  ? Colors
                                                                        .black87
                                                                  : Colors
                                                                        .black45)
                                                            : (note.isImportant
                                                                  ? Colors.black
                                                                  : Colors
                                                                        .black87),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    _buildCenterCircle(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCenterCircle() {
    final DateTime now = DateTime.now();

    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
        ],
        border: Border.all(color: Colors.black87, width: 2),
      ),
      child: ClipOval(
        child: Stack(
          children: [
            CustomPaint(
              size: const Size(180, 180),
              painter: YearProgressRingPainter(
                currentDate: now,
                monthDataList: _monthDataList,
              ),
            ),
            Center(
              child: Text(
                now.year.toString(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YearProgressRingPainter extends CustomPainter {
  final DateTime currentDate;
  final List<MonthData> monthDataList;

  YearProgressRingPainter({
    required this.currentDate,
    required this.monthDataList,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = math.min(size.width, size.height) / 2;

    final int currentMonth = currentDate.month;
    final int currentDay = currentDate.day;
    final int daysInCurrentMonth = DateTime(
      currentDate.year,
      currentMonth + 1,
      0,
    ).day;
    final double currentMonthProgress = currentDay / daysInCurrentMonth;

    final Paint slicePaint = Paint()..style = PaintingStyle.fill;
    final Rect rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final Paint dividerPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var data in monthDataList) {
      final double sliceStart = (data.angle - 15) * math.pi / 180;
      const double fullSweep = 30 * math.pi / 180;

      if (data.monthIndex < currentMonth) {
        slicePaint.color = Colors.grey.shade300;
        canvas.drawArc(rect, sliceStart, fullSweep, true, slicePaint);
      } else if (data.monthIndex == currentMonth) {
        final double greyAngle = fullSweep * currentMonthProgress;

        slicePaint.color = Colors.grey.shade300;
        canvas.drawArc(rect, sliceStart, greyAngle, true, slicePaint);

        slicePaint.color = Colors.white;
        canvas.drawArc(
          rect,
          sliceStart + greyAngle,
          fullSweep - greyAngle,
          true,
          slicePaint,
        );
      } else {
        slicePaint.color = Colors.white;
        canvas.drawArc(rect, sliceStart, fullSweep, true, slicePaint);
      }

      final Offset edge1 = Offset(
        cx + radius * math.cos(sliceStart),
        cy + radius * math.sin(sliceStart),
      );
      canvas.drawLine(Offset(cx, cy), edge1, dividerPaint);
    }

    final MonthData currentMonthData = monthDataList.firstWhere(
      (d) => d.monthIndex == currentMonth,
    );
    final double todayAngle =
        (currentMonthData.angle - 15) * math.pi / 180 +
        (30 * math.pi / 180) * currentMonthProgress;
    final Paint todayLinePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final Offset todayEdge = Offset(
      cx + radius * math.cos(todayAngle),
      cy + radius * math.sin(todayAngle),
    );
    canvas.drawLine(Offset(cx, cy), todayEdge, todayLinePaint);
  }

  @override
  bool shouldRepaint(covariant YearProgressRingPainter oldDelegate) {
    return oldDelegate.currentDate.day != currentDate.day ||
        oldDelegate.currentDate.month != currentDate.month ||
        oldDelegate.currentDate.year != currentDate.year;
  }
}

class CalendarConnectionPainter extends CustomPainter {
  final List<DailyNote> allNotes;
  final List<MonthData> monthDataList;
  final double slotHeight;
  final double startYOffset;
  final double cardOffset;
  final double cardHeight;
  final int currentMonth = DateTime.now().month;

  CalendarConnectionPainter({
    required this.allNotes,
    required this.monthDataList,
    required this.slotHeight,
    required this.startYOffset,
    required this.cardOffset,
    required this.cardHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double cx = size.width / 2;
    double cy = size.height / 2;

    double innerR = 90;
    double ringThickness = 28;
    double outerR = innerR + ringThickness;

    Paint linePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    Paint ringBackgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness;

    for (var data in monthDataList) {
      bool isPassed = data.monthIndex < currentMonth;
      ringBackgroundPaint.color = getMonthColorsHelper(
        data.name,
        isPassed,
      ).first.withOpacity(0.9);

      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(cx, cy),
          radius: innerR + ringThickness / 2,
        ),
        (data.angle - 15) * math.pi / 180,
        30 * math.pi / 180,
        false,
        ringBackgroundPaint,
      );
    }

    for (var data in monthDataList) {
      bool isPassed = data.monthIndex < currentMonth;

      double rad1 = (data.angle - 15) * math.pi / 180;
      double rad2 = (data.angle + 15) * math.pi / 180;

      Offset p1Outer = Offset(
        cx + outerR * math.cos(rad1),
        cy + outerR * math.sin(rad1),
      );
      Offset p2Outer = Offset(
        cx + outerR * math.cos(rad2),
        cy + outerR * math.sin(rad2),
      );

      Offset p1Inner = Offset(
        cx + innerR * math.cos(rad1),
        cy + innerR * math.sin(rad1),
      );
      Offset p2Inner = Offset(
        cx + innerR * math.cos(rad2),
        cy + innerR * math.sin(rad2),
      );

      canvas.drawLine(p1Inner, p1Outer, linePaint);
      canvas.drawLine(p2Inner, p2Outer, linePaint);

      Offset ringTop = p1Outer.dy < p2Outer.dy ? p1Outer : p2Outer;
      Offset ringBottom = p1Outer.dy > p2Outer.dy ? p1Outer : p2Outer;

      double centerY =
          startYOffset + (data.yIndex * slotHeight) + (slotHeight / 2);
      double cardTopY = centerY - (cardHeight / 2);
      double cardBottomY = centerY + (cardHeight / 2);

      double endX = data.isLeft ? (cx - cardOffset) : (cx + cardOffset);

      canvas.drawLine(ringTop, Offset(endX, cardTopY), linePaint);
      canvas.drawLine(ringBottom, Offset(endX, cardBottomY), linePaint);

      String displayText = "";
      final notes = allNotes
          .where((n) => n.date.month == data.monthIndex)
          .toList();
      if (notes.isNotEmpty) {
        notes.sort((a, b) => a.date.compareTo(b.date));
        displayText = "${notes.first.date.day} ${data.name}";
      } else {
        displayText = "${data.monthIndex} ${data.name}";
      }

      double textRad = innerR + ringThickness / 2;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(data.angle * math.pi / 180);
      canvas.translate(textRad, 0);
      canvas.rotate(math.pi / 2);

      TextSpan span = TextSpan(
        style: TextStyle(
          color: isPassed ? Colors.black54 : Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
        text: displayText,
      );
      TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(Offset(cx, cy), outerR, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MonthDetailScreen extends StatefulWidget {
  final String monthName;
  final int monthIndex;
  final List<DailyNote> notes;
  final ValueChanged<DailyNote> onNoteAdded;
  final ValueChanged<DailyNote> onNoteUpdated;
  final ValueChanged<DailyNote> onNoteDeleted;

  const MonthDetailScreen({
    Key? key,
    required this.monthName,
    required this.monthIndex,
    required this.notes,
    required this.onNoteAdded,
    required this.onNoteUpdated,
    required this.onNoteDeleted,
  }) : super(key: key);

  @override
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  late List<DailyNote> _notes;
  final TextEditingController _noteController = TextEditingController();
  late int _selectedDay;
  late int _daysInMonth;
  late int _noteYear;
  DailyNote? _editingNote;

  // 4. EKRAN DURUMU İÇİN ÖNEMLİ DEĞİŞKENİ
  bool _isImportantSelected = false;

  @override
  void initState() {
    super.initState();
    _notes = List.from(widget.notes);
    _noteYear = DateTime.now().year;
    _daysInMonth = DateTime(_noteYear, widget.monthIndex + 1, 0).day;
    _selectedDay = 1;
    _sortNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _sortNotes() {
    _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _saveNote() {
    final String content = _noteController.text.trim();
    if (content.isEmpty) return;

    if (_editingNote != null) {
      final DailyNote updatedNote = _editingNote!.copyWith(
        date: DateTime(_noteYear, widget.monthIndex, _selectedDay),
        noteContent: content,
        createdAt: DateTime.now(),
        isImportant: _isImportantSelected,
      );

      setState(() {
        final index = _notes.indexWhere((n) => n.id == updatedNote.id);
        if (index != -1) {
          _notes[index] = updatedNote;
        }
        _sortNotes();
        _noteController.clear();
        _editingNote = null;
        _isImportantSelected = false;
      });

      widget.onNoteUpdated(updatedNote);
    } else {
      final DailyNote newNote = DailyNote(
        date: DateTime(_noteYear, widget.monthIndex, _selectedDay),
        noteContent: content,
        isImportant: _isImportantSelected,
      );

      setState(() {
        _notes.add(newNote);
        _sortNotes();
        _noteController.clear();
        _isImportantSelected = false;
      });

      widget.onNoteAdded(newNote);
    }

    FocusScope.of(context).unfocus();
  }

  void _startEditing(DailyNote note) {
    setState(() {
      _editingNote = note;
      _selectedDay = note.date.day;
      _noteController.text = note.noteContent;
      _isImportantSelected =
          note.isImportant; // Notu düzenlerken mevcut yıldız durumunu koru
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingNote = null;
      _noteController.clear();
      _selectedDay = 1;
      _isImportantSelected = false;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _confirmDelete(DailyNote note) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu sil'),
        content: const Text('Bu notu silmek istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _notes.removeWhere((n) => n.id == note.id);
        if (_editingNote?.id == note.id) {
          _editingNote = null;
          _noteController.clear();
          _isImportantSelected = false;
        }
      });
      widget.onNoteDeleted(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = _editingNote != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.monthName} Notları'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _notes.isEmpty
                ? const Center(child: Text("Bu ay için henüz not alınmamış."))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      final bool isBeingEdited = _editingNote?.id == note.id;

                      // Liste ekranında önemli olan notun arkaplanını vurgula
                      Color? cardColor;
                      if (isBeingEdited) {
                        cardColor = Colors.blueGrey.shade50;
                      } else if (note.isImportant) {
                        cardColor = Colors.orange.shade50;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: cardColor,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: note.isImportant
                                ? Colors.deepOrangeAccent
                                : Colors.blueGrey,
                            child: Text(
                              note.date.day.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                DateFormat('dd MMMM yyyy').format(note.date),
                              ),
                              if (note.isImportant) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              note.noteContent,
                              style: TextStyle(
                                fontWeight: note.isImportant
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                color: Colors.blueGrey,
                                onPressed: () => _startEditing(note),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                color: Colors.redAccent,
                                onPressed: () => _confirmDelete(note),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (isEditing)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Not düzenleniyor',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelEditing,
                    child: const Text('Vazgeç'),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedDay,
                        items: List.generate(_daysInMonth, (i) => i + 1)
                            .map(
                              (day) => DropdownMenuItem<int>(
                                value: day,
                                child: Text(day.toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedDay = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText:
                            '${widget.monthName} $_selectedDay için not yaz...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  // 5. YILDIZ İŞARETLEME BUTONU
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isImportantSelected = !_isImportantSelected;
                      });
                    },
                    icon: Icon(
                      _isImportantSelected ? Icons.star : Icons.star_border,
                      color: _isImportantSelected ? Colors.amber : Colors.grey,
                    ),
                  ),

                  IconButton(
                    onPressed: _saveNote,
                    icon: Icon(isEditing ? Icons.check : Icons.send),
                    color: Colors.blueGrey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
