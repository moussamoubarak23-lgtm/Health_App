import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/theme.dart';
import 'package:table_calendar/table_calendar.dart';

class AppointmentsCalendarScreen extends StatefulWidget {
  const AppointmentsCalendarScreen({super.key});

  @override
  State<AppointmentsCalendarScreen> createState() => _AppointmentsCalendarScreenState();
}

class _AppointmentsCalendarScreenState extends State<AppointmentsCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    // On récupère toutes les consultations pour le calendrier
    final records = await OdooApi.getMedicalRecords();
    final Map<DateTime, List<dynamic>> eventSource = {};

    for (var record in records) {
      final dateStr = record['date_consultation']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          final day = DateTime(date.year, date.month, date.day);
          if (eventSource[day] == null) eventSource[day] = [];
          eventSource[day]!.add(record);
        } catch (e) {
          debugPrint("Error parsing date: $e");
        }
      }
    }

    setState(() {
      _events = eventSource;
      _isLoading = false;
    });
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const Sidebar(currentRoute: '/calendar'),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Calendrier des Rendez-vous", style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10)]),
                              child: TableCalendar(
                                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                                lastDay: DateTime.now().add(const Duration(days: 365)),
                                focusedDay: _focusedDay,
                                calendarFormat: _calendarFormat,
                                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });
                                },
                                onFormatChanged: (format) {
                                  setState(() => _calendarFormat = format);
                                },
                                eventLoader: _getEventsForDay,
                                calendarStyle: CalendarStyle(
                                  todayDecoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                                  todayTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                  selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  markerDecoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                                ),
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: true,
                                  titleCentered: true,
                                  formatButtonDecoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                                  formatButtonTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedDay == null ? "Sélectionnez un jour" : DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDay!),
                                    style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  const Divider(height: 32),
                                  if (_getEventsForDay(_selectedDay ?? _focusedDay).isEmpty)
                                    Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text("Aucun rendez-vous", style: GoogleFonts.dmSans(color: AppColors.textMuted))))
                                  else
                                    ..._getEventsForDay(_selectedDay ?? _focusedDay).map((event) => _appointmentTile(event)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentTile(Map event) {
    final time = DateTime.parse(event['date_consultation']).toLocal();
    final patientName = event['patient_id'] is List ? event['patient_id'][1] : "Patient Inconnu";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            child: Text(DateFormat('HH:mm').format(time), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(event['motif'] ?? "Consultation", style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecond), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }
}
