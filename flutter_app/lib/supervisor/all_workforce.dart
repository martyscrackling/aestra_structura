import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/file_download/file_download.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/sidebar.dart';

class AllWorkforcePage extends StatefulWidget {
	final int projectId;
	final String projectTitle;

	const AllWorkforcePage({
		super.key,
		required this.projectId,
		required this.projectTitle,
	});

	@override
	State<AllWorkforcePage> createState() => _AllWorkforcePageState();
}

class _WorkforceMember {
	_WorkforceMember({
		required this.name,
		required this.role,
		required this.email,
		required this.phone,
		required this.photoUrl,
		required this.workerId,
		required this.fieldWorkerId,
		required this.raw,
	});

	final String name;
	final String role;
	final String email;
	final String phone;
	final String photoUrl;
	final int? workerId;
	final int? fieldWorkerId;
	final Map<String, dynamic> raw;
	final Set<String> phaseNames = <String>{};
	int assignedSubtaskCount = 0;
}

class _AllWorkforcePageState extends State<AllWorkforcePage> {
	bool _isLoading = true;
	String? _error;
	List<_WorkforceMember> _workers = <_WorkforceMember>[];
	final Map<int, Map<String, dynamic>> _workerDetailsById =
			<int, Map<String, dynamic>>{};

	@override
	void initState() {
		super.initState();
		_loadAssignedWorkers();
	}

	int? _toInt(dynamic value) {
		if (value == null) return null;
		if (value is int) return value;
		if (value is num) return value.toInt();
		if (value is String) return int.tryParse(value);
		return int.tryParse(value.toString());
	}

	String _textOrEmpty(dynamic value) {
		final s = (value ?? '').toString().trim();
		if (s == 'null') return '';
		return s;
	}

	String _text(dynamic value, {String fallback = 'N/A'}) {
		final s = (value ?? '').toString().trim();
		if (s.isEmpty || s == 'null') return fallback;
		return s;
	}

	String _resolveMediaUrl(dynamic raw) {
		final value = (raw ?? '').toString().trim();
		if (value.isEmpty || value == 'null') return '';

		if (value.startsWith('http://') || value.startsWith('https://')) {
			return value;
		}

		final base = Uri.parse(AppConfig.apiBaseUrl);
		final origin = Uri(
			scheme: base.scheme,
			host: base.host,
			port: base.hasPort ? base.port : null,
		);

		if (value.startsWith('/')) return origin.resolve(value).toString();
		if (value.startsWith('media/')) return origin.resolve('/$value').toString();
		if (value.startsWith('client_images/')) {
			return origin.resolve('/media/$value').toString();
		}
		return origin.resolve('/media/$value').toString();
	}

	Future<void> _loadAssignedWorkers() async {
		try {
			final authUser = AuthService().currentUser;
			final userId = _toInt(authUser?['user_id']);
			final typeOrRole =
					(authUser?['type'] ?? authUser?['role'] ?? '')
						.toString()
						.trim()
						.toLowerCase();
			final supervisorId =
					_toInt(authUser?['supervisor_id']) ??
					((typeOrRole == 'supervisor') ? userId : null);

			final candidatePhaseUrls = <String>[
				if (userId != null)
					'phases/?project_id=${widget.projectId}&user_id=$userId',
				'phases/?project_id=${widget.projectId}',
			];

			http.Response? phasesResponse;
			for (final url in candidatePhaseUrls) {
				final response = await http.get(AppConfig.apiUri(url));
				if (response.statusCode == 200) {
					phasesResponse = response;
					break;
				}
			}

			if (phasesResponse == null) {
				setState(() {
					_error = 'Failed to load assigned workers.';
					_isLoading = false;
				});
				return;
			}

			final decoded = jsonDecode(phasesResponse.body);
			final phases = decoded is List<dynamic> ? decoded : <dynamic>[];

			final byKey = <String, _WorkforceMember>{};

			for (final phase in phases) {
				if (phase is! Map<String, dynamic>) continue;

				final phaseName = _text(phase['phase_name'], fallback: 'Unnamed Phase');
				final subtasks = phase['subtasks'] as List<dynamic>? ?? <dynamic>[];

				for (final subtask in subtasks) {
					if (subtask is! Map<String, dynamic>) continue;

					final assignedWorkers =
							subtask['assigned_workers'] as List<dynamic>? ?? <dynamic>[];

					for (final worker in assignedWorkers) {
						if (worker is! Map<String, dynamic>) continue;

						final workerId = _toInt(
							worker['worker_id'] ?? worker['id'] ?? worker['user_id'],
						);
						final fieldWorkerId = _toInt(
							worker['fieldworker_id'] ?? worker['worker_id'] ?? worker['id'],
						);
						final first = _text(worker['first_name'], fallback: '');
						final last = _text(worker['last_name'], fallback: '');
						final composedName = '$first $last'.trim();
						final role = _text(worker['role'], fallback: 'Worker');
						final name = composedName.isEmpty ? role : composedName;

						final key = workerId != null
								? 'id:$workerId'
								: 'name:${name.toLowerCase()}|${role.toLowerCase()}';

						final member = byKey.putIfAbsent(
							key,
							() => _WorkforceMember(
								name: name,
								role: role,
								email: _text(worker['email']),
								phone: _text(worker['phone_number']),
								photoUrl: _resolveMediaUrl(worker['photo']),
								workerId: workerId,
								fieldWorkerId: fieldWorkerId,
								raw: Map<String, dynamic>.from(worker),
							),
						);

						if (_textOrEmpty(member.raw['email']).isEmpty &&
								_textOrEmpty(worker['email']).isNotEmpty) {
							member.raw['email'] = worker['email'];
						}
						if (_textOrEmpty(member.raw['phone_number']).isEmpty &&
								_textOrEmpty(worker['phone_number']).isNotEmpty) {
							member.raw['phone_number'] = worker['phone_number'];
						}

						member.phaseNames.add(phaseName);
						member.assignedSubtaskCount += 1;
					}
				}
			}

			final workers = byKey.values.toList()
				..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

			// Preload full worker records so modal values don't fall back to partial
			// assigned_workers payload from phases.
			final fullWorkers = await _fetchProjectWorkersDirectory(
				userId: userId,
				supervisorId: supervisorId,
			);
			for (final item in fullWorkers) {
				final id = _toInt(item['fieldworker_id'] ?? item['worker_id'] ?? item['id']);
				if (id != null) {
					_workerDetailsById[id] = Map<String, dynamic>.from(item);
				}
			}
			for (final member in workers) {
				final id = member.fieldWorkerId ??
						_toInt(member.raw['fieldworker_id'] ?? member.raw['worker_id'] ?? member.raw['id']);
				if (id != null && _workerDetailsById.containsKey(id)) {
					member.raw.addAll(_workerDetailsById[id]!);
				}
			}

			if (!mounted) return;
			setState(() {
				_workers = workers;
				_isLoading = false;
			});
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_error = 'Unable to load workforce: $e';
				_isLoading = false;
			});
		}
	}

	Color _roleColor(String role) {
		switch (role) {
			case 'Painter':
				return const Color(0xFFFF6F00);
			case 'Electrician':
				return const Color(0xFF9E9E9E);
			case 'Plumber':
				return const Color(0xFF757575);
			case 'Carpenter':
				return const Color(0xFFFF8F00);
			default:
				return Colors.blueGrey;
		}
	}

	String _formatDate(String? dateString) {
		if (dateString == null || dateString.isEmpty) return 'N/A';
		try {
			final date = DateTime.parse(dateString);
			return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
		} catch (_) {
			return dateString;
		}
	}

	String _formatPayrate(dynamic payrate) {
		if (payrate == null) return 'Not set';
		return 'P$payrate/hr';
	}

	String _formatCurrency(dynamic value) {
		if (value == null) return 'Not set';
		final parsed = double.tryParse(value.toString());
		if (parsed == null) return 'Not set';
		return 'P${parsed.toStringAsFixed(2)}';
	}

	String _formatDeductionWithFallback(dynamic totalValue, dynamic minValue) {
		if (totalValue != null) return _formatCurrency(totalValue);
		if (minValue != null) return '${_formatCurrency(minValue)} (minimum)';
		return 'Not set';
	}

	String _buildWorkerQrPayload({required int fieldWorkerId}) {
		return 'structura-fw:$fieldWorkerId';
	}

	Future<void> _showWorkerQrDialog(
		BuildContext context, {
		required String workerName,
		required int fieldWorkerId,
	}) async {
		final repaintKey = GlobalKey();
		final payload = _buildWorkerQrPayload(fieldWorkerId: fieldWorkerId);

		await showDialog<void>(
			context: context,
			builder: (context) {
				return Dialog(
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(16),
					),
					child: ConstrainedBox(
						constraints: const BoxConstraints(maxWidth: 360),
						child: Padding(
							padding: const EdgeInsets.all(16),
							child: Column(
								mainAxisSize: MainAxisSize.min,
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									Row(
										children: [
											Expanded(
												child: Text(
													'QR Code - $workerName',
													style: const TextStyle(
														fontSize: 16,
														fontWeight: FontWeight.w700,
													),
													maxLines: 1,
													overflow: TextOverflow.ellipsis,
												),
											),
											IconButton(
												onPressed: () => Navigator.pop(context),
												icon: const Icon(Icons.close),
												splashRadius: 18,
											),
										],
									),
									const SizedBox(height: 8),
									Center(
										child: RepaintBoundary(
											key: repaintKey,
											child: Container(
												color: Colors.white,
												padding: const EdgeInsets.all(12),
												child: SizedBox(
													width: 220,
													height: 220,
													child: QrImageView(
														data: payload,
														version: QrVersions.auto,
														gapless: false,
													),
												),
											),
										),
									),
									const SizedBox(height: 12),
									Text(
										'Worker ID: $fieldWorkerId',
										textAlign: TextAlign.center,
										style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
									),
									const SizedBox(height: 16),
									Row(
										children: [
											Expanded(
												child: OutlinedButton(
													onPressed: () => Navigator.pop(context),
													child: const Text('Close'),
												),
											),
											const SizedBox(width: 12),
											Expanded(
												child: ElevatedButton.icon(
													onPressed: () async {
														try {
															final boundary =
																repaintKey.currentContext?.findRenderObject()
																	as RenderRepaintBoundary?;
															if (boundary == null) {
																throw Exception('QR render boundary not ready');
															}

															final ui.Image image = await boundary.toImage(
																pixelRatio: 3.0,
															);
															final byteData = await image.toByteData(
																format: ui.ImageByteFormat.png,
															);
															final Uint8List bytes = byteData!.buffer
																.asUint8List(
																	byteData.offsetInBytes,
																	byteData.lengthInBytes,
																);

															final safeName = workerName.trim().isEmpty
																? 'worker'
																: workerName.trim().replaceAll(
																		RegExp(r'[^a-zA-Z0-9_-]+'),
																		'_',
																);
															final filename =
																'qr_${safeName}_$fieldWorkerId.png';

															await downloadBytes(
																bytes: bytes,
																filename: filename,
																mimeType: 'image/png',
															);

															if (!context.mounted) return;
															ScaffoldMessenger.of(context).showSnackBar(
																SnackBar(
																	content: Text(
																		'QR code downloaded: $filename',
																	),
																),
															);
														} catch (e) {
															if (!context.mounted) return;
															final msg = kIsWeb
																? 'Failed to download QR: $e'
																: 'QR download is supported on web only';
															ScaffoldMessenger.of(
																context,
															).showSnackBar(SnackBar(content: Text(msg)));
														}
													},
													icon: const Icon(Icons.download),
													label: const Text('Download'),
													style: ElevatedButton.styleFrom(
														backgroundColor: const Color(0xFF1396E9),
													),
												),
											),
										],
									),
								],
							),
						),
					),
				);
			},
		);
	}

	Widget _buildDetailRow(String label, String value) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 8),
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceBetween,
				children: [
					Text(
						label,
						style: TextStyle(
							color: Colors.grey[600],
							fontWeight: FontWeight.w600,
							fontSize: 13,
						),
					),
					const SizedBox(width: 12),
					Expanded(
						child: Text(
							value,
							textAlign: TextAlign.right,
							style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
						),
					),
				],
			),
		);
	}

	Widget _buildDetailRowWithStatus(String label, String value, Color statusColor) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 8),
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceBetween,
				children: [
					Text(
						label,
						style: TextStyle(
							color: Colors.grey[600],
							fontWeight: FontWeight.w600,
							fontSize: 13,
						),
					),
					Container(
						padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
						decoration: BoxDecoration(
							color: statusColor.withOpacity(0.12),
							borderRadius: BorderRadius.circular(10),
						),
						child: Text(
							value,
							style: TextStyle(
								color: statusColor,
								fontWeight: FontWeight.w700,
								fontSize: 12,
							),
						),
					),
				],
			),
		);
	}

	Map<String, dynamic>? _firstRecordFromResponse(dynamic decoded) {
		if (decoded is Map<String, dynamic>) {
			if (decoded.containsKey('results') && decoded['results'] is List) {
				final results = decoded['results'] as List<dynamic>;
				if (results.isNotEmpty && results.first is Map) {
					return Map<String, dynamic>.from(results.first as Map);
				}
			}
			return Map<String, dynamic>.from(decoded);
		}

		if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
			return Map<String, dynamic>.from(decoded.first as Map);
		}

		return null;
	}

	List<Map<String, dynamic>> _recordsFromResponse(dynamic decoded) {
		if (decoded is List) {
			return decoded
				.whereType<Map>()
				.map((e) => Map<String, dynamic>.from(e))
				.toList();
		}

		if (decoded is Map<String, dynamic>) {
			final results = decoded['results'];
			if (results is List) {
				return results
					.whereType<Map>()
					.map((e) => Map<String, dynamic>.from(e))
					.toList();
			}
		}

		return <Map<String, dynamic>>[];
	}

	Future<List<Map<String, dynamic>>> _fetchProjectWorkersDirectory({
		required int? userId,
		required int? supervisorId,
	}) async {
		final candidateUrls = <String>[
			'field-workers/?project_id=${widget.projectId}',
			if (userId != null)
				'field-workers/?project_id=${widget.projectId}&user_id=$userId',
			if (supervisorId != null)
				'field-workers/?project_id=${widget.projectId}&supervisor_id=$supervisorId',
			if (supervisorId != null) 'field-workers/?supervisor_id=$supervisorId',
		];

		for (final url in candidateUrls) {
			final response = await http.get(AppConfig.apiUri(url));
			if (response.statusCode != 200) continue;

			final records = _recordsFromResponse(jsonDecode(response.body));
			if (records.isNotEmpty) return records;
		}

		return <Map<String, dynamic>>[];
	}

	Future<Map<String, dynamic>> _fetchWorkerDetails(_WorkforceMember worker) async {
		final authUser = AuthService().currentUser;
		final userId = _toInt(authUser?['user_id']);
		final projectId = _toInt(authUser?['project_id']) ?? widget.projectId;
		final typeOrRole =
				(authUser?['type'] ?? authUser?['role'] ?? '')
					.toString()
					.trim()
					.toLowerCase();
		final supervisorId =
				_toInt(authUser?['supervisor_id']) ??
				((typeOrRole == 'supervisor') ? userId : null);

		final fieldWorkerId =
				_toInt(worker.raw['fieldworker_id']) ?? worker.fieldWorkerId ?? worker.workerId;
		if (fieldWorkerId == null) {
			return Map<String, dynamic>.from(worker.raw);
		}

		if (_workerDetailsById.containsKey(fieldWorkerId)) {
			final merged = Map<String, dynamic>.from(worker.raw)
				..addAll(_workerDetailsById[fieldWorkerId]!);
			return merged;
		}

		// Prefer list endpoints with scope first: they are typically less restrictive
		// than detail endpoints for supervisor sessions.
		final candidateListUrls = <String>[
			if (supervisorId != null)
				'field-workers/?supervisor_id=$supervisorId',
			if (projectId != null) 'field-workers/?project_id=$projectId',
			if (userId != null) 'field-workers/?user_id=$userId',
			'field-workers/',
		];

		for (final url in candidateListUrls) {
			final response = await http.get(AppConfig.apiUri(url));
			if (response.statusCode != 200) continue;

			final records = _recordsFromResponse(jsonDecode(response.body));
			for (final record in records) {
				final id = _toInt(
					record['fieldworker_id'] ?? record['worker_id'] ?? record['id'],
				);
				if (id == fieldWorkerId) {
					if (id != null) {
						_workerDetailsById[id] = Map<String, dynamic>.from(record);
					}
					final merged = Map<String, dynamic>.from(worker.raw)..addAll(record);
					return merged;
				}
			}
		}

		final candidateUrls = <String>[
			if (supervisorId != null)
				'field-workers/$fieldWorkerId/?supervisor_id=$supervisorId',
			if (projectId != null) 'field-workers/$fieldWorkerId/?project_id=$projectId',
			if (userId != null) 'field-workers/$fieldWorkerId/?user_id=$userId',
			'field-workers/$fieldWorkerId/',
		];

		for (final url in candidateUrls) {
			final response = await http.get(AppConfig.apiUri(url));
			if (response.statusCode == 200) {
				final mapped = _firstRecordFromResponse(jsonDecode(response.body));
				if (mapped != null) {
					final id = _toInt(
						mapped['fieldworker_id'] ?? mapped['worker_id'] ?? mapped['id'],
					);
					if (id != null) {
						_workerDetailsById[id] = Map<String, dynamic>.from(mapped);
					}
					final merged = Map<String, dynamic>.from(worker.raw)..addAll(mapped);
					return merged;
				}
			}
		}

		if (projectId != null) {
			final listResponse = await http.get(
				AppConfig.apiUri('field-workers/?project_id=$projectId'),
			);
			if (listResponse.statusCode == 200) {
				final decoded = jsonDecode(listResponse.body);
				if (decoded is List) {
					for (final item in decoded) {
						if (item is! Map<String, dynamic>) continue;
						final id = _toInt(item['fieldworker_id'] ?? item['worker_id'] ?? item['id']);
						if (id == fieldWorkerId) {
							if (id != null) {
								_workerDetailsById[id] = Map<String, dynamic>.from(item);
							}
							final merged = Map<String, dynamic>.from(worker.raw)..addAll(item);
							return merged;
						}
					}
				}
			}
		}

		return Map<String, dynamic>.from(worker.raw);
	}

	Future<void> _showWorkerDetailModal(BuildContext context, _WorkforceMember worker) async {
		showDialog<void>(
			context: context,
			barrierDismissible: false,
			builder: (_) => const Center(child: CircularProgressIndicator()),
		);

		Map<String, dynamic> details = Map<String, dynamic>.from(worker.raw);
		try {
			final fetched = await _fetchWorkerDetails(worker);
			details = Map<String, dynamic>.from(details)..addAll(fetched);
		} catch (_) {
			// Keep fallback data from phase payload.
		}

		if (!mounted) return;
		Navigator.of(context, rootNavigator: true).pop();
		if (!context.mounted) return;
		_showWorkerDetailModalWithData(context, worker, details);
	}

	void _showWorkerDetailModalWithData(
		BuildContext context,
		_WorkforceMember worker,
		Map<String, dynamic> raw,
	) {
		final roleColor = _roleColor(worker.role);
		final workerName = worker.name;
		final middleName = _text(raw['middle_name']);
		final phoneNumber = _text(raw['phone_number']);
		final birthdate = _formatDate(_textOrEmpty(raw['birthdate']));
		final sssId = _text(raw['sss_id']);
		final philhealthId = _text(raw['philhealth_id']);
		final pagibigId = _text(raw['pagibig_id']);
		final payrate = _formatPayrate(raw['payrate']);
		final cashAdvanceBalance = _formatCurrency(raw['cash_advance_balance']);
		final deductionPerSalary = _formatCurrency(raw['deduction_per_salary']);
		final dateHired = _formatDate(_textOrEmpty(raw['created_at']));
		final region = _text(raw['region']);
		final province = _text(raw['province']);
		final city = _text(raw['city']);
		final barangay = _text(raw['barangay']);
		final sssDeduction = _formatDeductionWithFallback(
			raw['sss_weekly_total'],
			raw['sss_weekly_min'],
		);
		final philhealthDeduction = _formatDeductionWithFallback(
			raw['philhealth_weekly_total'],
			raw['philhealth_weekly_min'],
		);
		final pagibigDeduction = _formatDeductionWithFallback(
			raw['pagibig_weekly_total'],
			raw['pagibig_weekly_min'],
		);
		final weeklySalary = _formatCurrency(raw['weekly_salary']);
		final sssWeeklyMin = _formatCurrency(raw['sss_weekly_min']);
		final philhealthWeeklyMin = _formatCurrency(raw['philhealth_weekly_min']);
		final pagibigWeeklyMin = _formatCurrency(raw['pagibig_weekly_min']);
		final totalWeeklyDeduction = _formatCurrency(raw['total_weekly_deduction']);
		final netWeeklyPay = _formatCurrency(raw['net_weekly_pay']);
		final fieldWorkerId =
			_toInt(raw['fieldworker_id']) ?? worker.fieldWorkerId ?? worker.workerId;

		showDialog(
			context: context,
			builder: (context) {
				return Dialog(
					shape: RoundedRectangleBorder(
						borderRadius: BorderRadius.circular(16),
					),
					child: Container(
						constraints: const BoxConstraints(maxWidth: 640),
						child: SingleChildScrollView(
							child: Padding(
								padding: const EdgeInsets.all(20),
								child: Column(
									mainAxisSize: MainAxisSize.min,
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Row(
											mainAxisAlignment: MainAxisAlignment.spaceBetween,
											children: [
												Row(
													children: [
														Container(
															width: 8,
															height: 48,
															decoration: BoxDecoration(
																color: roleColor.withOpacity(0.95),
																borderRadius: BorderRadius.circular(6),
															),
														),
														const SizedBox(width: 12),
														const Text(
															'Worker Profile',
															style: TextStyle(
																fontSize: 18,
																fontWeight: FontWeight.w700,
															),
														),
													],
												),
												IconButton(
													icon: const Icon(Icons.close),
													onPressed: () => Navigator.pop(context),
													padding: EdgeInsets.zero,
													constraints: const BoxConstraints(),
												),
											],
										),
										const SizedBox(height: 18),
										Center(
											child: Column(
												children: [
													Container(
														width: 110,
														height: 110,
														decoration: BoxDecoration(
															color: roleColor.withOpacity(0.12),
															borderRadius: BorderRadius.circular(20),
														),
														child: worker.photoUrl.isEmpty
															? Icon(
																	Icons.person,
																	size: 56,
																	color: roleColor,
																)
															: ClipRRect(
																	borderRadius: BorderRadius.circular(20),
																	child: Image.network(
																		worker.photoUrl,
																		fit: BoxFit.cover,
																		errorBuilder: (_, __, ___) => Icon(
																			Icons.person,
																			size: 56,
																			color: roleColor,
																		),
																	),
																),
														),
													const SizedBox(height: 14),
													Text(
														workerName,
														style: const TextStyle(
															fontSize: 20,
															fontWeight: FontWeight.w800,
														),
													),
													const SizedBox(height: 6),
													Container(
														padding: const EdgeInsets.symmetric(
															horizontal: 12,
															vertical: 6,
														),
														decoration: BoxDecoration(
															color: roleColor.withOpacity(0.12),
															borderRadius: BorderRadius.circular(12),
														),
														child: Text(
															worker.role,
															style: TextStyle(
																color: roleColor,
																fontWeight: FontWeight.w700,
																fontSize: 13,
															),
														),
													),
												],
											),
										),
										const SizedBox(height: 20),
										const Divider(),
										const SizedBox(height: 12),
										const Text(
											'Personal Information',
											style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
										),
										const SizedBox(height: 12),
										_buildDetailRow('Middle Name', middleName),
										_buildDetailRow('Phone', phoneNumber),
										_buildDetailRow('Birthdate', birthdate),
										_buildDetailRow('Region', region),
										_buildDetailRow('Province', province),
										_buildDetailRow('City', city),
										_buildDetailRow('Barangay', barangay),
										_buildDetailRow('SSS ID', sssId),
										_buildDetailRow('PhilHealth ID', philhealthId),
										_buildDetailRow('Pag-IBIG ID', pagibigId),
										_buildDetailRow('SSS Deduction (Weekly)', sssDeduction),
										_buildDetailRow(
											'PhilHealth Deduction (Weekly)',
											philhealthDeduction,
										),
										_buildDetailRow('Pag-IBIG Deduction (Weekly)', pagibigDeduction),
										const SizedBox(height: 12),
										const Text(
											'Work Details',
											style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
										),
										const SizedBox(height: 12),
										_buildDetailRow('Project', widget.projectTitle),
										_buildDetailRow('Date Hired', dateHired),
										_buildDetailRow('Payrate (Hourly)', payrate),
										_buildDetailRow('Cash Advance Balance', cashAdvanceBalance),
										_buildDetailRow('Deduction per Salary', deductionPerSalary),
										_buildDetailRow('Weekly Salary', weeklySalary),
										_buildDetailRow('SSS Weekly Minimum', sssWeeklyMin),
										_buildDetailRow('PhilHealth Weekly Minimum', philhealthWeeklyMin),
										_buildDetailRow('Pag-IBIG Weekly Minimum', pagibigWeeklyMin),
										_buildDetailRow('Total Weekly Deduction', totalWeeklyDeduction),
										_buildDetailRow('Net Weekly Pay', netWeeklyPay),
										_buildDetailRow('Assigned Subtasks', '${worker.assignedSubtaskCount}'),
										_buildDetailRowWithStatus('Status', 'Active', Colors.green),
										const SizedBox(height: 18),
										Row(
											children: [
												Expanded(
													child: OutlinedButton.icon(
														onPressed: fieldWorkerId == null
															? null
															: () => _showWorkerQrDialog(
																	context,
																	workerName: workerName,
																	fieldWorkerId: fieldWorkerId,
																),
														icon: const Icon(Icons.qr_code),
														label: const Text('Download QR'),
														style: OutlinedButton.styleFrom(
															padding: const EdgeInsets.symmetric(vertical: 14),
															side: const BorderSide(color: Color(0xFF1396E9)),
														),
													),
												),
												const SizedBox(width: 12),
												ElevatedButton.icon(
													onPressed: () => Navigator.pop(context),
													icon: const Icon(Icons.check),
													label: const Text('Close'),
													style: ElevatedButton.styleFrom(
														backgroundColor: const Color(0xFF1396E9),
														padding: const EdgeInsets.symmetric(vertical: 14),
													),
												),
											],
										),
										const SizedBox(height: 8),
									],
								),
							),
						),
					),
				);
			},
		);
	}

	Widget _buildAvatar(_WorkforceMember worker) {
		if (worker.photoUrl.isEmpty) {
			return CircleAvatar(
				radius: 24,
				backgroundColor: Colors.grey.shade200,
				child: Icon(Icons.person_outline, color: Colors.grey.shade600),
			);
		}

		return CircleAvatar(
			radius: 24,
			backgroundImage: NetworkImage(worker.photoUrl),
			backgroundColor: Colors.grey.shade200,
			onBackgroundImageError: (_, __) {},
			child: const SizedBox.shrink(),
		);
	}

	Widget _buildBody(bool isMobile) {
		if (_isLoading) {
			return const Center(child: CircularProgressIndicator());
		}

		if (_error != null) {
			return Center(
				child: Padding(
					padding: const EdgeInsets.all(24),
					child: Text(
						_error!,
						style: const TextStyle(color: Color(0xFFB91C1C)),
						textAlign: TextAlign.center,
					),
				),
			);
		}

		if (_workers.isEmpty) {
			return const Center(
				child: Padding(
					padding: EdgeInsets.all(24),
					child: Text(
						'No workers are assigned to this project yet.',
						style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
						textAlign: TextAlign.center,
					),
				),
			);
		}

		return ListView.separated(
			padding: EdgeInsets.all(isMobile ? 16 : 24),
			itemCount: _workers.length,
			separatorBuilder: (_, __) => const SizedBox(height: 12),
			itemBuilder: (_, index) {
				final worker = _workers[index];
				final roleColor = _roleColor(worker.role);
				return Container(
					padding: const EdgeInsets.all(14),
					decoration: BoxDecoration(
						color: Colors.white,
						borderRadius: BorderRadius.circular(12),
						border: Border.all(color: Colors.grey.shade200),
					),
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							_buildAvatar(worker),
							const SizedBox(width: 12),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											worker.name,
											style: const TextStyle(
												fontSize: 16,
												fontWeight: FontWeight.w700,
											),
										),
										const SizedBox(height: 4),
										Text(
											worker.role,
											style: TextStyle(
												fontSize: 13,
												color: roleColor,
												fontWeight: FontWeight.w600,
											),
										),
										const SizedBox(height: 6),
										Text(
											'Email: ${worker.email}',
											style: const TextStyle(
												fontSize: 12,
												color: Color(0xFF6B7280),
											),
										),
										Text(
											'Phone: ${worker.phone}',
											style: const TextStyle(
												fontSize: 12,
												color: Color(0xFF6B7280),
											),
										),
										const SizedBox(height: 10),
										Wrap(
											spacing: 8,
											runSpacing: 8,
											children: [
												Container(
													padding: const EdgeInsets.symmetric(
														horizontal: 10,
														vertical: 6,
													),
													decoration: BoxDecoration(
														color: const Color(0xFFFFF3E0),
														borderRadius: BorderRadius.circular(999),
													),
													child: Text(
														'Phases: ${worker.phaseNames.length}',
														style: const TextStyle(
															fontSize: 12,
															fontWeight: FontWeight.w600,
															color: Color(0xFFE65100),
														),
													),
												),
												Container(
													padding: const EdgeInsets.symmetric(
														horizontal: 10,
														vertical: 6,
													),
													decoration: BoxDecoration(
														color: const Color(0xFFE8F5E9),
														borderRadius: BorderRadius.circular(999),
													),
													child: Text(
														'Assigned tasks: ${worker.assignedSubtaskCount}',
														style: const TextStyle(
															fontSize: 12,
															fontWeight: FontWeight.w600,
															color: Color(0xFF2E7D32),
														),
													),
												),
											],
										),
									],
								),
							),
							const SizedBox(width: 12),
							Column(
								children: [
									OutlinedButton(
										onPressed: () => _showWorkerDetailModal(context, worker),
										style: OutlinedButton.styleFrom(
											foregroundColor: const Color(0xFFFF6F00),
											side: const BorderSide(color: Color(0xFFFF6F00)),
											padding: const EdgeInsets.symmetric(
												horizontal: 12,
												vertical: 10,
											),
										),
										child: const Text(
											'View More',
											style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
										),
									),
								],
							),
						],
					),
				);
			},
		);
	}

	@override
	Widget build(BuildContext context) {
		final width = MediaQuery.of(context).size.width;
		final isDesktop = width > 1024;
		final isMobile = width < 768;

		return Scaffold(
			backgroundColor: const Color(0xFFF4F6F9),
			body: Row(
				children: [
					if (isDesktop)
						const Sidebar(activePage: 'Projects', keepVisible: true),
					Expanded(
						child: Column(
							children: [
								DashboardHeader(onMenuPressed: () {}, title: 'Projects'),
								Padding(
									padding: EdgeInsets.fromLTRB(
										isMobile ? 12 : 20,
										12,
										isMobile ? 12 : 20,
										8,
									),
									child: Row(
										children: [
											IconButton(
												onPressed: () => Navigator.of(context).pop(),
												icon: const Icon(Icons.arrow_back),
											),
											const SizedBox(width: 8),
											Expanded(
												child: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														const Text(
															'All Workforce',
															style: TextStyle(
																fontSize: 20,
																fontWeight: FontWeight.w700,
																color: Color(0xFF0C1935),
															),
														),
														Text(
															widget.projectTitle,
															maxLines: 1,
															overflow: TextOverflow.ellipsis,
															style: const TextStyle(
																fontSize: 13,
																color: Color(0xFF6B7280),
															),
														),
													],
												),
											),
											if (!_isLoading && _error == null)
												Container(
													padding: const EdgeInsets.symmetric(
														horizontal: 12,
														vertical: 8,
													),
													decoration: BoxDecoration(
														color: Colors.white,
														borderRadius: BorderRadius.circular(999),
														border: Border.all(color: Colors.grey.shade300),
													),
													child: Text(
														'${_workers.length} worker${_workers.length == 1 ? '' : 's'}',
														style: const TextStyle(
															fontWeight: FontWeight.w600,
															color: Color(0xFF374151),
														),
													),
												),
										],
									),
								),
								const Divider(height: 1),
								Expanded(child: _buildBody(isMobile)),
							],
						),
					),
				],
			),
		);
	}
}
