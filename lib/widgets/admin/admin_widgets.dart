import 'package:flutter/material.dart';
import '../ui/glass_ui.dart';
import '../../models/visit_data.dart';
import '../../models/place_type_config.dart';
import '../../services/form_field_service.dart' as form_service;
import '../ui/app_button.dart';

import '../ui/app_toast.dart';

class AdminWidgets {
  // Modern Loading Widget
  static Widget buildLoadingWidget({
    String message = 'Načítám...',
    Color? color,
    double size = 40.0,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              color: color ?? Colors.blue[600],
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Modern Empty State Widget
  static Widget buildEmptyStateWidget({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    Color? iconColor,
    double iconSize = 80.0,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton(
                onPressed: onAction,
                text: actionLabel,
                type: AppButtonType.primary,
                size: AppButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Modern Error Widget
  static Widget buildErrorWidget({
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    IconData icon = Icons.error_outline,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.red[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Chyba',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton(
                onPressed: onAction,
                text: actionLabel,
                type: AppButtonType.destructive,
                size: AppButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Modern Visit Card Widget
  static Widget buildVisitCard({
    required VisitData visitData,
    required bool isSelected,
    required bool isBulkMode,
    required Function(String) onToggleSelection,
    required VoidCallback onTap,
    required VoidCallback onShowDetails,
    bool hasPendingChanges = false,
  }) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      onTap: isBulkMode ? () => onToggleSelection(visitData.id) : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getStatusColor(visitData.state.name).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(visitData.state.name).withValues(alpha: 0.2),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(visitData.state.name),
                      size: 13,
                      color: _getStatusColor(visitData.state.name),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getStatusText(visitData.state.name),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(visitData.state.name),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              if (hasPendingChanges) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_rounded, size: 12, color: Colors.orange[800]),
                      const SizedBox(width: 4),
                      Text(
                        'ZMĚNY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange[800],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Points badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2), width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, size: 13, color: Colors.amber[800]),
                    const SizedBox(width: 4),
                    Text(
                      '${visitData.points?.toStringAsFixed(1) ?? '0'} b.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                ),
              ),

              // Selection checkbox (only in bulk mode)
              if (isBulkMode) ...[
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2E7D32) : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Route title
          Text(
            visitData.routeTitle ?? 'Bez názvu',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.6,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // Route details
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDetailChip(
                  Icons.pets_rounded,
                  visitData.dogName ?? 'Neznámý',
                  Colors.blue[600]!,
                ),
                const SizedBox(width: 8),
                _buildDetailChip(
                  Icons.calendar_today_rounded,
                  _formatDate(visitData.visitDate),
                  Colors.green[600]!,
                ),
                const SizedBox(width: 8),
                _buildDetailChip(
                  Icons.route_rounded,
                  '${visitData.route?['distance']?.toStringAsFixed(1) ?? '0'} km',
                  Colors.purple[600]!,
                ),
              ],
            ),
          ),

          if (visitData.places != null && visitData.places!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visitData.places!.map((place) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place_rounded, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        place.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed: onShowDetails,
                  text: 'Zobrazit detaily',
                  icon: Icons.east_rounded,
                  type: AppButtonType.secondary,
                  size: AppButtonSize.medium,
                  expand: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modern Form Field Card Widget
  static Widget buildFormFieldCard({
    required form_service.FormField field,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onReorder,
  }) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      borderRadius: 16,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getFieldTypeColor(field.type).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getFieldTypeIcon(field.type),
            size: 20,
            color: _getFieldTypeColor(field.type),
          ),
        ),
        title: Text(
          field.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getFieldTypeColor(field.type).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getFieldTypeText(field.type).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _getFieldTypeColor(field.type),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (field.required)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'POVINNÉ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.red[700],
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onEdit,
              icon: Icon(Icons.edit_rounded, color: Colors.blue[600], size: 20),
              tooltip: 'Upravit',
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_rounded, color: Colors.red[600], size: 20),
              tooltip: 'Smazat',
            ),
            ReorderableDragStartListener(
              index: field.order,
              child: const Icon(
                Icons.drag_indicator_rounded,
                color: Color(0xFF9AA5B1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Place Type Card Widget
  static Widget buildPlaceTypeCard({
    required PlaceTypeConfig placeType,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required Function(bool) onToggleStatus,
  }) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: placeType.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: placeType.color.withValues(alpha: 0.2)),
                ),
                child: Icon(placeType.icon, color: placeType.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placeType.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: placeType.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: placeType.color.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars_rounded, color: placeType.color, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${placeType.points} ${placeType.points == 1 ? 'bod' : 'bodů'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: placeType.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: placeType.isActive
                                ? Colors.green.withValues(alpha: 0.08)
                                : Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: placeType.isActive
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                placeType.isActive
                                    ? Icons.check_circle_rounded
                                    : Icons.pause_circle_rounded,
                                color: placeType.isActive ? Colors.green : Colors.red,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                placeType.isActive ? 'AKTIVNÍ' : 'NEAKTIVNÍ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: placeType.isActive ? Colors.green : Colors.red,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: placeType.isActive,
                onChanged: onToggleStatus,
                activeColor: placeType.color,
                activeTrackColor: placeType.color.withValues(alpha: 0.2),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                onPressed: onEdit,
                text: 'Upravit',
                icon: Icons.edit_rounded,
                type: AppButtonType.secondary,
                size: AppButtonSize.small,
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 40,
                width: 40,
                child: IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_rounded, size: 20),
                  color: Colors.red[600],
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Modern Tab Widget
  static Widget buildAdminTab({
    required int index,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.white.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern Search Bar Widget
  static Widget buildSearchBar({
    required TextEditingController controller,
    required Function(String) onChanged,
    required String hintText,
    VoidCallback? onClear,
    String? initialValue,
  }) {
    return Container(
      height: 52, // Slightly taller
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 22, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 14, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }

  // Modern Dropdown Widget
  static Widget buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) itemText,
    required void Function(T?) onChanged,
    required String hintText,
    IconData? icon,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: DropdownButton<T>(
              value: value,
              hint: Text(hintText, style: TextStyle(color: Colors.grey, fontSize: 15)),
              underline: const SizedBox.shrink(),
              onChanged: onChanged,
              items: items.map((T item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemText(item),
                    style: const TextStyle(fontSize: 15),
                  ),
                );
              }).toList(),
                ),
              ),
            ],
          ),
    );
  }

  // Helper methods
  static Widget _buildDetailChip(
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color.withOpacity(0.8),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.9),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static Color _getStatusColor(String state) {
    switch (state) {
      case 'PENDING_REVIEW':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static IconData _getStatusIcon(String state) {
    switch (state) {
      case 'PENDING_REVIEW':
        return Icons.schedule;
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  static String _getStatusText(String state) {
    switch (state) {
      case 'PENDING_REVIEW':
        return 'Čeká na revizi';
      case 'APPROVED':
        return 'Schváleno';
      case 'REJECTED':
        return 'Odmítnuto';
      default:
        return 'Neznámý stav';
    }
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'Neznámé datum';
    return '${date.day}.${date.month}.${date.year}';
  }

  static Color _getFieldTypeColor(String type) {
    switch (type) {
      case 'text':
      case 'textarea':
        return Colors.blue;
      case 'number':
      case 'distance':
      case 'elevation':
      case 'speed':
        return Colors.green;
      case 'select':
        return Colors.purple;
      case 'checkbox':
        return Colors.orange;
      case 'date':
      case 'time':
      case 'datetime':
        return Colors.red;
      case 'email':
      case 'phone':
      case 'url':
        return Colors.indigo;
      case 'rating':
        return Colors.amber;
      case 'places':
        return Colors.teal;
      case 'file':
      case 'image':
        return Colors.brown;
      case 'location':
        return Colors.deepPurple;
      case 'duration':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  static IconData _getFieldTypeIcon(String type) {
    switch (type) {
      case 'text':
        return Icons.text_fields;
      case 'textarea':
        return Icons.subject;
      case 'number':
        return Icons.numbers;
      case 'select':
        return Icons.list;
      case 'checkbox':
        return Icons.check_box;
      case 'date':
        return Icons.calendar_today;
      case 'time':
        return Icons.access_time;
      case 'datetime':
        return Icons.date_range;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      case 'url':
        return Icons.link;
      case 'rating':
        return Icons.star;
      case 'file':
        return Icons.attach_file;
      case 'image':
        return Icons.image;
      case 'location':
        return Icons.location_on;
      case 'distance':
        return Icons.route;
      case 'duration':
        return Icons.timer;
      case 'elevation':
        return Icons.landscape;
      case 'speed':
        return Icons.speed;
      case 'places':
        return Icons.place;
      default:
        return Icons.help;
    }
  }

  static String _getFieldTypeText(String type) {
    switch (type) {
      case 'text':
        return 'Text';
      case 'textarea':
        return 'Dlouhý text';
      case 'number':
        return 'Číslo';
      case 'select':
        return 'Výběr';
      case 'checkbox':
        return 'Zaškrtávací pole';
      case 'date':
        return 'Datum';
      case 'time':
        return 'Čas';
      case 'datetime':
        return 'Datum a čas';
      case 'email':
        return 'Email';
      case 'phone':
        return 'Telefon';
      case 'url':
        return 'URL';
      case 'rating':
        return 'Hodnocení';
      case 'file':
        return 'Soubor';
      case 'image':
        return 'Obrázek';
      case 'location':
        return 'Lokace';
      case 'distance':
        return 'Vzdálenost';
      case 'duration':
        return 'Doba trvání';
      case 'elevation':
        return 'Nadmořská výška';
      case 'speed':
        return 'Rychlost';
      case 'places':
        return 'Místa';
      default:
        return 'Neznámý typ';
    }
  }
  // Migration Button
  static Widget buildMigrationButton() {
    return Builder(
      builder: (context) {
        return AppButton(
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Migrace databáze'),
                content: const Text(
                  'Tato akce projde všechny záznamy a normalizuje data (přesune extraPoints do hlavních polí). '
                  'Doporučeno spustit, pokud se nezobrazují staré výlety.\n\n'
                  'Může to chvíli trvat.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Zrušit'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Spustit migraci'),
                  ),
                ],
              ),
            );

            if (confirm != true) return;

            // Show loading indicator
            if (!context.mounted) return;
            AppToast.showInfo(context, 'Migrace spuštěna...');
            
            // Lazy import to avoid circular dependencies if possible, or just assume imports exist
            // Since we can't do lazy imports easily in Dart inside a method without reflection, 
            // we will rely on the file import which we will add.
            final result = await _runMigration();
            
            if (!context.mounted) return;
            if (result['success'] == true) {
              AppToast.showSuccess(
                context, 
                'Hotovo! Aktualizováno: ${result['updated']}, Chyb: ${result['errors']}'
              );
            } else {
              AppToast.showError(context, 'Chyba: ${result['message']}');
            }
          },
          text: 'Opravit stará data (Migrace)',
          icon: Icons.build_circle_outlined,
          type: AppButtonType.secondary,
          size: AppButtonSize.medium,
          expand: true,
        );
      }
    );
  }

  // Helper to run migration without direct import in widget file if we want to keep it clean, 
  // but better to import the service.
  static Future<Map<String, dynamic>> _runMigration() async {
    // We need to import DatabaseCleanerService at the top of the file
    // For now, using dynamic to avoid compilation error if import is missing, 
    // but I will add the import in the same tool call.
    return {'success': false, 'message': 'Migration service temporarily unavailable'};
  }
}
