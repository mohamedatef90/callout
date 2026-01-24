import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/whisper_colors.dart';

class FolderChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const FolderChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withOpacity(0.2)
                    : WhisperColors.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? color : WhisperColors.cardBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? WhisperColors.textPrimary
                          : WhisperColors.textSecondary,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.3)
                            : WhisperColors.cardBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: WhisperColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FolderChipList extends StatelessWidget {
  final List<FolderChipData> folders;
  final String? selectedFolderId;
  final Function(String?) onFolderSelected;

  const FolderChipList({
    super.key,
    required this.folders,
    this.selectedFolderId,
    required this.onFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // "All" chip
          FolderChip(
            label: 'All',
            count: folders.fold(0, (sum, folder) => sum + folder.count),
            color: WhisperColors.amber,
            isSelected: selectedFolderId == null,
            onTap: () => onFolderSelected(null),
          ),
          const SizedBox(width: 8),

          // Folder chips
          ...folders.map((folder) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FolderChip(
                  label: folder.name,
                  count: folder.count,
                  color: folder.color,
                  isSelected: selectedFolderId == folder.id,
                  onTap: () => onFolderSelected(folder.id),
                ),
              )),

          // Add folder chip
          FolderChip(
            label: '+',
            count: 0,
            color: WhisperColors.textMuted,
            onTap: () {
              // TODO: Open create folder dialog
            },
          ),
        ],
      ),
    );
  }
}

class FolderChipData {
  final String id;
  final String name;
  final int count;
  final Color color;

  FolderChipData({
    required this.id,
    required this.name,
    required this.count,
    required this.color,
  });
}
