import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/expense_provider.dart';
import '../services/ocr_service.dart';
import 'widgets/category_selector_widget.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, this.editing});

  static const String routeName = '/add-transaction';

  /// Neu khac null => man hinh o che do SUA giao dich.
  final TransactionModel? editing;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final OcrService _ocrService = OcrService();

  TransactionType _type = TransactionType.expense;
  int? _categoryId;
  DateTime _date = DateTime.now();

  bool _isSaving = false;
  bool _isScanning = false;
  String? _ocrSummary;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final TransactionModel? editing = widget.editing;
    if (editing != null) {
      _type = editing.type;
      _categoryId = editing.categoryId;
      _date = editing.date;
      _titleController.text = editing.title;
      _noteController.text = editing.note;
      _amountController.text =
          Formatters.plainNumber.format(editing.amount.round());
    } else {
      // Lay danh muc mac dinh sau khi CategoryProvider da nap xong.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final CategoryProvider cp = context.read<CategoryProvider>();
        setState(() => _categoryId ??= cp.defaultCategoryId(_type));
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // ==========================================================================
  // OCR
  // ==========================================================================

  Future<void> _openScanSheet() async {
    final ImageSourceType? source = await showModalBottomSheet<ImageSourceType>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quét hoá đơn',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Chụp bằng camera'),
              subtitle: const Text('Đặt hoá đơn trên nền phẳng, đủ sáng'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSourceType.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Chọn ảnh có sẵn'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImageSourceType.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;
    await _runOcr(source);
  }

  Future<void> _runOcr(ImageSourceType source) async {
    setState(() {
      _isScanning = true;
      _ocrSummary = null;
    });

    try {
      final ScannedReceipt? result = await _ocrService.scanReceipt(source);
      if (!mounted) return;

      if (result == null) {
        setState(() => _isScanning = false);
        return;
      }

      if (result.isEmpty || !result.hasAnyData) {
        setState(() => _isScanning = false);
        _showMessage(
          'Không đọc được dữ liệu từ ảnh. Hãy chụp lại rõ nét và thẳng góc hơn.',
          isError: true,
        );
        return;
      }

      final List<String> filled = <String>[];

      if (result.amount != null && result.amount! > 0) {
        _amountController.text =
            Formatters.plainNumber.format(result.amount!.round());
        filled.add('số tiền');
      }
      if (result.date != null) {
        _date = result.date!;
        filled.add('ngày');
      }
      if (result.merchant != null && result.merchant!.trim().isNotEmpty) {
        _titleController.text = _prettifyMerchant(result.merchant!);
        filled.add('đơn vị bán');
      }

      setState(() {
        _isScanning = false;
        _ocrSummary = filled.isEmpty
            ? null
            : 'Đã tự điền: ${filled.join(', ')}. Vui lòng kiểm tra lại trước khi lưu.';
      });
    } on OcrException catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      _showMessage(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      _showMessage('Lỗi khi quét hoá đơn: $e', isError: true);
    }
  }

  /// "CONG TY TNHH ABC" -> "Cong Ty Tnhh Abc" nhin de chiu hon tren the.
  String _prettifyMerchant(String raw) {
    final String cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 3) return cleaned;
    if (cleaned == cleaned.toUpperCase()) {
      return cleaned
          .split(' ')
          .map((String w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
          .join(' ');
    }
    return cleaned;
  }

  // ==========================================================================
  // LUU
  // ==========================================================================

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Chọn ngày giao dịch',
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  void _onTypeChanged(TransactionType type) {
    final CategoryProvider cp = context.read<CategoryProvider>();
    setState(() {
      _type = type;
      // Doi danh muc ve mac dinh cua loai moi, tranh luu danh muc sai loai.
      _categoryId = cp.defaultCategoryId(type);
    });
  }

  Future<void> _pickCategory() async {
    final int? picked = await CategorySelector.pick(
      context,
      type: _type,
      selectedId: _categoryId,
    );
    if (picked != null) setState(() => _categoryId = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final ExpenseProvider provider = context.read<ExpenseProvider>();
    final NavigatorState navigator = Navigator.of(context);

    final CategoryProvider cp = context.read<CategoryProvider>();
    final int? categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _isSaving = false);
      _showMessage('Vui lòng chọn danh mục.', isError: true);
      return;
    }

    final double amount = Formatters.parseInput(_amountController.text);
    final String title = _titleController.text.trim().isEmpty
        ? cp.byId(categoryId).name
        : _titleController.text.trim();

    try {
      if (_isEditing) {
        final TransactionModel updated = widget.editing!.copyWith(
          title: title,
          amount: amount,
          date: _date,
          categoryId: categoryId,
          type: _type,
          note: _noteController.text.trim(),
        );
        await provider.updateTransaction(updated);
        if (!mounted) return;
        navigator.pop();
      } else {
        final TransactionModel item = TransactionModel.create(
          title: title,
          amount: amount,
          date: _date,
          categoryId: categoryId,
          type: _type,
          note: _noteController.text.trim(),
        );
        final BudgetAlertLevel alert = await provider.addTransaction(item);
        if (!mounted) return;
        navigator.pop(alert);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Không lưu được giao dịch: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppTheme.expenseColor : null,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ==========================================================================
  // UI
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final CategoryProvider categoryProvider = context.watch<CategoryProvider>();
    final CategoryModel? selectedCategory =
        _categoryId == null ? null : categoryProvider.byId(_categoryId!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              // ---------- Loai giao dich ----------
              SegmentedButton<TransactionType>(
                segments: const <ButtonSegment<TransactionType>>[
                  ButtonSegment<TransactionType>(
                    value: TransactionType.expense,
                    label: Text('Khoản chi'),
                    icon: Icon(Icons.trending_down_rounded),
                  ),
                  ButtonSegment<TransactionType>(
                    value: TransactionType.income,
                    label: Text('Khoản thu'),
                    icon: Icon(Icons.trending_up_rounded),
                  ),
                ],
                selected: <TransactionType>{_type},
                onSelectionChanged: (Set<TransactionType> value) =>
                    _onTypeChanged(value.first),
              ),
              const SizedBox(height: 18),

              // ---------- Nut quet hoa don ----------
              if (_type.isExpense) ...<Widget>[
                OutlinedButton.icon(
                  onPressed: _isScanning ? null : _openScanSheet,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_rounded),
                  label: Text(
                    _isScanning ? 'Đang đọc hoá đơn...' : 'Quét hoá đơn (OCR)',
                  ),
                ),
                if (_ocrSummary != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.auto_awesome_rounded,
                            size: 18, color: scheme.onTertiaryContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _ocrSummary!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
              ],

              // ---------- So tien ----------
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: <ThousandsInputFormatter>[
                  ThousandsInputFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  hintText: '0',
                  suffixText: '₫',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (String? value) {
                  final double amount = Formatters.parseInput(value ?? '');
                  if (amount <= 0) return 'Nhập số tiền lớn hơn 0';
                  if (amount > 999999999999) return 'Số tiền quá lớn';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ---------- Tieu de ----------
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nội dung / đơn vị bán',
                  hintText: 'VD: Siêu thị Co.opmart',
                  prefixIcon: Icon(Icons.storefront_outlined),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),

              // ---------- Ngay ----------
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày giao dịch',
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(
                    Formatters.date(_date),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ---------- Danh muc ----------
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Danh mục',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickCategory,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selectedCategory?.color.withOpacity(0.5) ??
                          scheme.outlineVariant,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: (selectedCategory?.color ?? scheme.primary)
                              .withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          selectedCategory?.icon ?? Icons.category_rounded,
                          color: selectedCategory?.color ?? scheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _categoryId == null
                              ? 'Chọn danh mục'
                              : categoryProvider.displayName(_categoryId!),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _categoryId == null
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ---------- Ghi chu ----------
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 140,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (không bắt buộc)',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isEditing ? 'Cập nhật' : 'Lưu giao dịch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
