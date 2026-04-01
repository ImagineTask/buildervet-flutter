import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/task_model.dart';

// ─────────────────────────────────────────────
// Line Item Model
// ─────────────────────────────────────────────

class _LineItem {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _LineItem({
    String descriptionText = '',
    String quantityText = '1',
    String unitPriceText = '0',
  })  : description = TextEditingController(text: descriptionText),
        quantity = TextEditingController(text: quantityText),
        unitPrice = TextEditingController(text: unitPriceText);

  double get total {
    final q = double.tryParse(quantity.text) ?? 0;
    final p = double.tryParse(unitPrice.text) ?? 0;
    return q * p;
  }

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }

  Map<String, dynamic> toMap() => {
        'description': description.text,
        'quantity': double.tryParse(quantity.text) ?? 1,
        'unitPrice': double.tryParse(unitPrice.text) ?? 0,
        'total': total,
      };
}

// ─────────────────────────────────────────────
// CreateInvoicePage
// ─────────────────────────────────────────────

class CreateInvoicePage extends StatefulWidget {
  final TaskModel project;
  final String? invoiceId;

  const CreateInvoicePage({
    super.key,
    required this.project,
    this.invoiceId,
  });

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _sortCodeController = TextEditingController();
  final _invoiceNumberController = TextEditingController();
  final _paymentTermsController =
      TextEditingController(text: 'Payment due within 30 days');
  final _notesController = TextEditingController();
  final _vatRateController = TextEditingController(text: '20');

  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _vatEnabled = true;
  bool _loading = true;
  bool _saving = false;
  List<_LineItem> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _sortCodeController.dispose();
    _invoiceNumberController.dispose();
    _paymentTermsController.dispose();
    _notesController.dispose();
    _vatRateController.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  // ── Load data ────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? {};

      _companyNameController.text =
          userData['company'] as String? ??
              userData['name'] as String? ??
              '';
      _companyAddressController.text =
          userData['address'] as String? ?? '';
      _companyEmailController.text =
          userData['email'] as String? ?? '';
      _companyPhoneController.text =
          userData['phone'] as String? ?? '';
      _bankNameController.text =
          userData['bankName'] as String? ?? '';
      _accountNumberController.text =
          userData['accountNumber'] as String? ?? '';
      _sortCodeController.text =
          userData['sortCode'] as String? ?? '';

      if (widget.invoiceId != null) {
        await _loadExistingInvoice(widget.invoiceId!);
      } else {
        await _prefillFromTasks();
        _invoiceNumberController.text =
            DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadExistingInvoice(String invoiceId) async {
    final doc = await FirebaseFirestore.instance
        .collection('invoices')
        .doc(invoiceId)
        .get();
    final data = doc.data();
    if (data == null) return;

    _invoiceNumberController.text =
        data['invoiceNumber'] as String? ?? '';
    _paymentTermsController.text =
        data['paymentTerms'] as String? ?? '';
    _notesController.text = data['notes'] as String? ?? '';
    _vatEnabled = data['vatEnabled'] as bool? ?? true;
    _vatRateController.text =
        (data['vatRate'] as num?)?.toString() ?? '20';

    if (data['issueDate'] != null) {
      _issueDate =
          DateTime.tryParse(data['issueDate'] as String) ?? _issueDate;
    }
    if (data['dueDate'] != null) {
      _dueDate =
          DateTime.tryParse(data['dueDate'] as String) ?? _dueDate;
    }

    final items = List<Map<String, dynamic>>.from(
        data['lineItems'] as List? ?? []);
    _lineItems = items
        .map((item) => _LineItem(
              descriptionText: item['description'] as String? ?? '',
              quantityText:
                  (item['quantity'] as num?)?.toString() ?? '1',
              unitPriceText:
                  (item['unitPrice'] as num?)?.toString() ?? '0',
            ))
        .toList();
  }

  Future<void> _prefillFromTasks() async {
    final snap = await FirebaseFirestore.instance
        .collection('tasks')
        .where('parentTaskId', isEqualTo: widget.project.taskId)
        .where('taskType', isEqualTo: 'task')
        .get();

    _lineItems = [];
    for (final doc in snap.docs) {
      final task = TaskModel.fromFirestore(doc);
      if (task.hasAgreedPrice) {
        _lineItems.add(_LineItem(
          descriptionText: task.taskName,
          quantityText: '1',
          unitPriceText: (task.agreedTotal ?? 0).toStringAsFixed(2),
        ));
      }
    }

    if (_lineItems.isEmpty) _lineItems.add(_LineItem());
  }

  // ── Calculations ─────────────────────────────────────────────────

  double get _subtotal =>
      _lineItems.fold(0, (sum, item) => sum + item.total);

  double get _vatAmount {
    if (!_vatEnabled) return 0;
    final rate = double.tryParse(_vatRateController.text) ?? 0;
    return _subtotal * rate / 100;
  }

  double get _total => _subtotal + _vatAmount;

  // ── Date picker ──────────────────────────────────────────────────

  Future<void> _pickDate(bool isIssue) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isIssue ? _issueDate : _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: Color(0xFF6C63FF)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isIssue) {
          _issueDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  // ── Save profile ─────────────────────────────────────────────────

  Future<void> _saveBuilderProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'company': _companyNameController.text.trim(),
      'address': _companyAddressController.text.trim(),
      'phone': _companyPhoneController.text.trim(),
      'bankName': _bankNameController.text.trim(),
      'accountNumber': _accountNumberController.text.trim(),
      'sortCode': _sortCodeController.text.trim(),
    });
  }

  // ── Generate, save & preview ─────────────────────────────────────

  Future<void> _generateAndSave() async {
    setState(() => _saving = true);

    try {
      await _saveBuilderProfile();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final pdfBytes = await _buildPdf();

      // Save to temp file & upload to Storage
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/invoice_${_invoiceNumberController.text}.pdf');
      await file.writeAsBytes(pdfBytes);

      final storageRef = FirebaseStorage.instance.ref().child(
          'invoices/${widget.project.taskId}/${_invoiceNumberController.text}.pdf');
      await storageRef.putFile(file);
      final pdfUrl = await storageRef.getDownloadURL();

      // Save to Firestore
      final invoiceData = {
        'projectId': widget.project.taskId,
        'projectName': widget.project.taskName,
        'builderId': uid,
        'builderName': _companyNameController.text.trim(),
        'invoiceNumber': _invoiceNumberController.text.trim(),
        'issueDate': _issueDate.toIso8601String(),
        'dueDate': _dueDate.toIso8601String(),
        'lineItems': _lineItems.map((i) => i.toMap()).toList(),
        'subtotal': _subtotal,
        'vatEnabled': _vatEnabled,
        'vatRate': double.tryParse(_vatRateController.text) ?? 0,
        'vatAmount': _vatAmount,
        'total': _total,
        'paymentTerms': _paymentTermsController.text.trim(),
        'notes': _notesController.text.trim(),
        'bankName': _bankNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'sortCode': _sortCodeController.text.trim(),
        'pdfUrl': pdfUrl,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (widget.invoiceId != null) {
        await FirebaseFirestore.instance
            .collection('invoices')
            .doc(widget.invoiceId)
            .update(invoiceData);
      } else {
        await FirebaseFirestore.instance
            .collection('invoices')
            .add(invoiceData);
      }

      if (mounted) {
        // Pop back to invoice list first
        Navigator.pop(context);

        // Show bottom sheet PDF preview
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => PdfBottomSheet(
            pdfBytes: pdfBytes,
            invoiceName: 'Invoice_${_invoiceNumberController.text}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build PDF ────────────────────────────────────────────────────

  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document();
    final vatRate = double.tryParse(_vatRateController.text) ?? 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          // ── Header ──────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _companyNameController.text.isNotEmpty
                        ? _companyNameController.text
                        : 'Your Company',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('6C63FF'),
                    ),
                  ),
                  if (_companyAddressController.text.isNotEmpty)
                    pw.Text(_companyAddressController.text,
                        style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600)),
                  if (_companyEmailController.text.isNotEmpty)
                    pw.Text(_companyEmailController.text,
                        style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600)),
                  if (_companyPhoneController.text.isNotEmpty)
                    pw.Text(_companyPhoneController.text,
                        style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('INVOICE',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      )),
                  pw.Text('#${_invoiceNumberController.text}',
                      style: const pw.TextStyle(
                          fontSize: 13,
                          color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Divider(
              color: PdfColor.fromHex('6C63FF'), thickness: 1.5),
          pw.SizedBox(height: 16),

          // ── Dates ────────────────────────────────────────────
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Issue Date',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600)),
                    pw.Text(
                        '${_issueDate.day}/${_issueDate.month}/${_issueDate.year}',
                        style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Due Date',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600)),
                    pw.Text(
                        '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                        style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Project',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600)),
                    pw.Text(widget.project.taskName,
                        style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // ── Line items table ────────────────────────────────
          pw.Table(
            border: null,
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('6C63FF')),
                children: [
                  _pdfCell('Description', isHeader: true),
                  _pdfCell('Qty', isHeader: true),
                  _pdfCell('Unit Price', isHeader: true),
                  _pdfCell('Total', isHeader: true),
                ],
              ),
              ..._lineItems.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i % 2 == 0
                        ? PdfColors.grey100
                        : PdfColors.white,
                  ),
                  children: [
                    _pdfCell(item.description.text),
                    _pdfCell(item.quantity.text),
                    _pdfCell('£${item.unitPrice.text}'),
                    _pdfCell(
                        '£${item.total.toStringAsFixed(2)}'),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Totals ──────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 220,
              child: pw.Column(
                children: [
                  _pdfTotalRow('Subtotal',
                      '£${_subtotal.toStringAsFixed(2)}'),
                  if (_vatEnabled)
                    _pdfTotalRow('VAT ($vatRate%)',
                        '£${_vatAmount.toStringAsFixed(2)}'),
                  pw.Divider(
                      color: PdfColor.fromHex('6C63FF'),
                      thickness: 1),
                  _pdfTotalRow(
                    'Total',
                    '£${_total.toStringAsFixed(2)}',
                    isBold: true,
                    color: PdfColor.fromHex('6C63FF'),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 30),

          // ── Payment terms ────────────────────────────────────
          if (_paymentTermsController.text.isNotEmpty) ...[
            pw.Text('Payment Terms',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: PdfColors.grey800)),
            pw.SizedBox(height: 4),
            pw.Text(_paymentTermsController.text,
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
          ],

          // ── Bank details ─────────────────────────────────────
          if (_bankNameController.text.isNotEmpty ||
              _accountNumberController.text.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('F5F5FF'),
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8)),
                border: pw.Border.all(
                    color: PdfColor.fromHex('6C63FF'),
                    width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bank Details',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          color: PdfColor.fromHex('6C63FF'))),
                  pw.SizedBox(height: 6),
                  if (_bankNameController.text.isNotEmpty)
                    _pdfBankRow(
                        'Bank', _bankNameController.text),
                  if (_accountNumberController.text.isNotEmpty)
                    _pdfBankRow('Account Number',
                        _accountNumberController.text),
                  if (_sortCodeController.text.isNotEmpty)
                    _pdfBankRow(
                        'Sort Code', _sortCodeController.text),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Notes ────────────────────────────────────────────
          if (_notesController.text.isNotEmpty) ...[
            pw.Text('Notes',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: PdfColors.grey800)),
            pw.SizedBox(height: 4),
            pw.Text(_notesController.text,
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey700)),
          ],
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight:
              isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.grey800,
        ),
      ),
    );
  }

  pw.Widget _pdfTotalRow(String label, String value,
      {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: isBold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: color ?? PdfColors.grey700,
              )),
          pw.Text(value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: isBold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
                color: color ?? PdfColors.grey700,
              )),
        ],
      ),
    );
  }

  pw.Widget _pdfBankRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.Text(value,
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  // ── Build UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF6C63FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.invoiceId != null ? 'Edit Invoice' : 'New Invoice',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _generateAndSave,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Save & Generate PDF',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            title: 'Your Business Details',
            icon: Icons.business_outlined,
            children: [
              _field('Company Name', _companyNameController),
              _field('Address', _companyAddressController,
                  maxLines: 2),
              _field('Email', _companyEmailController,
                  keyboardType: TextInputType.emailAddress),
              _field('Phone', _companyPhoneController,
                  keyboardType: TextInputType.phone),
            ],
          ),
          const SizedBox(height: 16),

          _sectionCard(
            title: 'Invoice Details',
            icon: Icons.receipt_outlined,
            children: [
              _field('Invoice Number', _invoiceNumberController),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _datePicker(
                      label: 'Issue Date',
                      date: _issueDate,
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _datePicker(
                      label: 'Due Date',
                      date: _dueDate,
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          _sectionCard(
            title: 'Line Items',
            icon: Icons.list_alt_outlined,
            trailing: TextButton.icon(
              onPressed: () =>
                  setState(() => _lineItems.add(_LineItem())),
              icon: const Icon(Icons.add,
                  size: 16, color: Color(0xFF6C63FF)),
              label: const Text('Add',
                  style: TextStyle(color: Color(0xFF6C63FF))),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: const [
                    Expanded(
                        flex: 4,
                        child: Text('Description',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey))),
                    SizedBox(width: 8),
                    SizedBox(
                        width: 50,
                        child: Text('Qty',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey))),
                    SizedBox(width: 8),
                    SizedBox(
                        width: 80,
                        child: Text('Price (£)',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey))),
                    SizedBox(width: 32),
                  ],
                ),
              ),
              ..._lineItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: _inlineField(item.description,
                            hint: 'Task or item'),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        child: _inlineField(item.quantity,
                            hint: '1',
                            keyboardType: TextInputType.number),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: _inlineField(item.unitPrice,
                            hint: '0.00',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          item.dispose();
                          _lineItems.removeAt(index);
                        }),
                        child: const Icon(Icons.close,
                            size: 18,
                            color: Color(0xFFFF6B6B)),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),
              _totalRow('Subtotal',
                  '£${_subtotal.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: _vatEnabled,
                    onChanged: (v) =>
                        setState(() => _vatEnabled = v),
                    activeColor: const Color(0xFF6C63FF),
                  ),
                  const Text('VAT',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  const SizedBox(width: 8),
                  if (_vatEnabled)
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _vatRateController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          suffixText: '%',
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF6C63FF),
                                width: 1.5),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  const Spacer(),
                  if (_vatEnabled)
                    Text(
                      '£${_vatAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const Divider(height: 8),
              _totalRow(
                  'Total', '£${_total.toStringAsFixed(2)}',
                  isBold: true,
                  color: const Color(0xFF6C63FF)),
            ],
          ),
          const SizedBox(height: 16),

          _sectionCard(
            title: 'Payment Terms',
            icon: Icons.schedule_outlined,
            children: [
              _field('Terms', _paymentTermsController,
                  maxLines: 2),
            ],
          ),
          const SizedBox(height: 16),

          _sectionCard(
            title: 'Bank Details',
            icon: Icons.account_balance_outlined,
            children: [
              _field('Bank Name', _bankNameController),
              _field('Account Number', _accountNumberController,
                  keyboardType: TextInputType.number),
              _field('Sort Code', _sortCodeController,
                  keyboardType: TextInputType.number),
            ],
          ),
          const SizedBox(height: 16),

          _sectionCard(
            title: 'Notes',
            icon: Icons.notes_outlined,
            children: [
              _field('Additional notes', _notesController,
                  maxLines: 3),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── UI Helpers ───────────────────────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  )),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(fontSize: 13, color: Colors.grey[500]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFF6C63FF), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _inlineField(
    TextEditingController controller, {
    String hint = '',
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(fontSize: 12, color: Colors.grey[400]),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
              color: Color(0xFF6C63FF), width: 1.5),
        ),
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 14, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[500])),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Colors.grey[700],
            )),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Colors.grey[700],
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// PDF Bottom Sheet Viewer
// Public so InvoiceManagementPage can reuse it
// ─────────────────────────────────────────────

class PdfBottomSheet extends StatelessWidget {
  final Uint8List pdfBytes;
  final String invoiceName;

  const PdfBottomSheet({
    super.key,
    required this.pdfBytes,
    required this.invoiceName,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle + header ──────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFF6C63FF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        invoiceName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.grey, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── PDF preview ──────────────────────────────────
          Expanded(
            child: PdfPreview(
              build: (_) async => pdfBytes,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              actions: const [],
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              pdfPreviewPageDecoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),

          // ── Download button ──────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 12),
            child: FilledButton.icon(
              onPressed: () async {
                await Printing.sharePdf(
                  bytes: pdfBytes,
                  filename: '$invoiceName.pdf',
                );
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text(
                'Download / Share',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}