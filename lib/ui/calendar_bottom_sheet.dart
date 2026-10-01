import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../providers/conversation_list_provider.dart';



class CalendarBottomSheet extends ConsumerStatefulWidget {
  const CalendarBottomSheet({super.key});

  @override
  ConsumerState<CalendarBottomSheet> createState() => _CalendarBottomSheetState();
}

class _CalendarBottomSheetState extends ConsumerState<CalendarBottomSheet> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getEventsForDay(DateTime day, List<ConversationModel> realConvs) {
    final hasRealRecord = realConvs.any((c) => isSameDay(c.date, day));
    return hasRealRecord ? ['대화 기록 있음'] : [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final convAsync = ref.watch(conversationListProvider);
    final realConvs = convAsync.asData?.value ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('나의 기록', style: theme.textTheme.displayMedium),
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search, size: 32),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) _searchController.clear();
                    });
                  },
                ),
              ],
            ),
          ),

          if (_isSearching)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '대화 내용을 검색해보세요',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),

          if (!_isSearching)
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              daysOfWeekHeight: 38,
              rowHeight: 56,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: (day) => _getEventsForDay(day, realConvs),
              calendarStyle: CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                // 32px 컴팩트 하이라이트 원 (하단 점과 겹침 완벽 방지)
                selectedBuilder: (context, date, focusedDay) {
                  return Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
                todayBuilder: (context, date, focusedDay) {
                  return Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    bottom: 3,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                headerPadding: EdgeInsets.symmetric(vertical: 12.0),
              ),
            ),

          const Divider(height: 24, thickness: 1),

          Expanded(
            child: _buildListView(theme, realConvs),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(ThemeData theme, List<ConversationModel> realConvs) {
    if (_selectedDay != null && _getEventsForDay(_selectedDay!, realConvs).isNotEmpty) {
      final matchingConvs = realConvs.where((c) => isSameDay(c.date, _selectedDay!)).toList();

      if (matchingConvs.isNotEmpty) {
        return ListView.builder(
          itemCount: matchingConvs.length,
          itemBuilder: (context, index) {
            final conv = matchingConvs[index];
            final timeStr = DateFormat('a hh:mm', 'ko_KR').format(conv.createdAt);
            final dateStr = DateFormat('yyyy년 MM월 dd일').format(conv.date);

            return _buildListItem(
              theme,
              context,
              '$dateStr $timeStr',
              conv.summary,
              conv.messages,
            );
          },
        );
      }
    }

    return Center(
      child: Text(
        _selectedDay == null 
            ? '날짜를 선택해주세요' 
            : '이 날에는 대화 기록이 없습니다.',
        style: TextStyle(color: Colors.grey[600], fontSize: 18),
      ),
    );
  }

  Widget _buildListItem(
    ThemeData theme,
    BuildContext context,
    String title,
    String summary,
    List<ChatMessageModel>? messages,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push(
            '/detail',
            extra: {
              'date': _selectedDay ?? DateTime.now(),
              'summary': summary,
              'messages': messages,
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 28, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
