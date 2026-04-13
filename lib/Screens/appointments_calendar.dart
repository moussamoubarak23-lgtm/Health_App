import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/Services/odoo_api.dart';
import 'package:medical_app/Widgets/sidebar.dart';
import 'package:medical_app/theme.dart';
import 'package:medical_app/app_localizations.dart';
import 'package:medical_app/Widgets/app_breadcrumb.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<dynamic> _allPatients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      OdooApi.getMedicalRecords(),
      OdooApi.getPatients(),
    ]);
    
    final records = results[0];
    _allPatients = results[1];
    
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

  void _showEditAppointmentDialog(Map event, AppLocalizations loc) {
    final initialDateTime = DateTime.parse(event['date_consultation']).toLocal();
    DateTime selectedDate = DateTime(initialDateTime.year, initialDateTime.month, initialDateTime.day);
    TimeOfDay selectedTime = TimeOfDay(hour: initialDateTime.hour, minute: initialDateTime.minute);
    final motifCtrl = TextEditingController(text: event['motif'] ?? "Consultation");

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [const Icon(Icons.edit_calendar_rounded, color: AppColors.primary), const SizedBox(width: 10), Text(loc.t('editAppointment'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18))]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${loc.t('colPatient')}: ${event['patient_id'] is List ? event['patient_id'][1] : loc.t('unknownPatient')}", style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: motifCtrl,
                  decoration: InputDecoration(labelText: loc.t('appointmentReason'), prefixIcon: const Icon(Icons.notes_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (date != null) setDialogState(() => selectedDate = date);
                  },
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.event, size: 18, color: AppColors.primary), const SizedBox(width: 12), Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: GoogleFonts.dmSans())])),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: selectedTime);
                    if (time != null) setDialogState(() => selectedTime = time);
                  },
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary), const SizedBox(width: 12), Text(selectedTime.format(context), style: GoogleFonts.dmSans())])),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
            ElevatedButton(
              onPressed: () async {
                final scheduledDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                
                showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
                
                final res = await OdooApi.updateMedicalRecord(
                  recordId: event['id'],
                  motif: motifCtrl.text.trim(),
                  diagnostic: event['diagnostic'] ?? '',
                  prescription: event['prescription'] ?? '',
                  observations: event['observations'] ?? '',
                  state: event['state'] ?? 'waiting',
                  medicalFileNumber: event['medical_file_number'] ?? '',
                  datetime: scheduledDateTime.toString().substring(0, 19),
                );
                
                if (mounted) Navigator.pop(context); // Close loader
                if (mounted) Navigator.pop(context); // Close dialog
                
                if (res['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('updatedAppointmentSuccess'))));
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(loc.t('save')),
            )
          ],
        ),
      ),
    );
  }

  void _showScheduleAppointmentDialog(AppLocalizations loc) {
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final motifCtrl = TextEditingController(text: "Consultation");
    Map? selectedPatient;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [const Icon(Icons.calendar_month_rounded, color: AppColors.primary), const SizedBox(width: 10), Text(loc.t('scheduleAppointment'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 18))]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Map>(
                  decoration: InputDecoration(labelText: loc.t('selectPatientLabel'), prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  value: selectedPatient,
                  items: _allPatients.map((p) => DropdownMenuItem<Map>(value: p, child: Text(p['name'] ?? ''))).toList(),
                  onChanged: (val) => setDialogState(() => selectedPatient = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: motifCtrl,
                  decoration: InputDecoration(labelText: loc.t('appointmentReason'), prefixIcon: const Icon(Icons.notes_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (date != null) setDialogState(() => selectedDate = date);
                  },
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.event, size: 18, color: AppColors.primary), const SizedBox(width: 12), Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: GoogleFonts.dmSans())])),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: selectedTime);
                    if (time != null) setDialogState(() => selectedTime = time);
                  },
                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary), const SizedBox(width: 12), Text(selectedTime.format(context), style: GoogleFonts.dmSans())])),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
            ElevatedButton(
              onPressed: selectedPatient == null ? null : () async {
                final scheduledDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                final prefs = await SharedPreferences.getInstance();
                final doctorId = prefs.getInt('uid') ?? 0;
                
                showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
                
                final res = await OdooApi.addMedicalRecord(
                  patientId: selectedPatient!['id'],
                  doctorId: doctorId,
                  datetime: scheduledDateTime.toString().substring(0, 19),
                  consultationReason: motifCtrl.text.trim(),
                  diagnostic: '',
                  prescription: '',
                  observations: '',
                  status: 'waiting',
                  medicalFileNumber: (selectedPatient!['medical_file_number'] ?? selectedPatient!['ref'] ?? '').toString(),
                );
                
                if (mounted) Navigator.pop(context); // Close loader
                if (mounted) Navigator.pop(context); // Close dialog
                
                if (res['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('plannedAppointmentSuccess'))));
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(loc.t('scheduleAppointment')),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.t('appointmentCalendarTitle'), style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          ElevatedButton.icon(
                            onPressed: () => _showScheduleAppointmentDialog(loc),
                            icon: const Icon(Icons.add_task_rounded),
                            label: Text(loc.t('scheduleRdv')),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppBreadcrumb(
                        items: [
                          BreadcrumbItem(label: loc.t('home'), route: '/dashboard'),
                          BreadcrumbItem(label: loc.t('calendarLabel')),
                        ],
                      ),
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
                                calendarStyle: const CalendarStyle(
                                  outsideDaysVisible: false,
                                ),
                                calendarBuilders: CalendarBuilders(
                                  selectedBuilder: (context, date, _) {
                                    return Center(
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                        width: 28,
                                        height: 28,
                                        child: Text('${date.day}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    );
                                  },
                                  todayBuilder: (context, date, _) {
                                    return Center(
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                                        width: 28,
                                        height: 28,
                                        child: Text('${date.day}', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    );
                                  },
                                  markerBuilder: (context, date, events) {
                                    return const SizedBox.shrink(); // MASQUE LES POINTS VERTS
                                  },
                                ),
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: true,
                                  titleCentered: true,
                                  formatButtonDecoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                                  formatButtonTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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
                                    Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text(loc.t('noAppointment'), style: GoogleFonts.dmSans(color: AppColors.textMuted))))
                                  else
                                    ..._getEventsForDay(_selectedDay ?? _focusedDay).map((event) => _appointmentTile(event, loc)),
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

  Widget _appointmentTile(Map event, AppLocalizations loc) {
    final time = DateTime.parse(event['date_consultation']).toLocal();
    final patientName = event['patient_id'] is List ? event['patient_id'][1] : "Patient Inconnu";
    
    return InkWell(
      onTap: () => _showEditAppointmentDialog(event, loc),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
