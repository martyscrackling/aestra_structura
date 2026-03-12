import 'package:flutter/material.dart';
import '../inventory_page.dart';

class ToolDetailsModal extends StatelessWidget {
  const ToolDetailsModal({super.key, required this.tool});

  final ToolItem tool;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tool.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0C1935),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (tool.photoUrl != null && tool.photoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  tool.photoUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.construction,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.construction, size: 80, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 24),
            _buildInfoRow('Category', tool.category),
            const SizedBox(height: 12),
            if (tool.serialNumber != null && tool.serialNumber!.isNotEmpty) ...[
              _buildInfoRow('Serial Number', tool.serialNumber!),
              const SizedBox(height: 12),
            ],
            _buildInfoRow('Quantity', tool.quantity.toString()),
            const SizedBox(height: 12),
            if (tool.location != null && tool.location!.isNotEmpty) ...[
              _buildInfoRow('Location', tool.location!),
              const SizedBox(height: 12),
            ],
            if (tool.notes != null && tool.notes!.isNotEmpty) ...[
              _buildInfoRow('Notes', tool.notes!),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0C1935),
                  ),
                ),
                _statusChip(tool.status),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A18),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0C1935),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final lower = status.toLowerCase();
    final color = lower == 'available'
        ? Colors.green
        : lower == 'maintenance'
        ? Colors.orange
        : lower == 'returned'
        ? Colors.blue
        : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
