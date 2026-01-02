import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/smart_list.dart';
import '../../state/app_state.dart';
import '../../state/layout_density.dart';
import '../../core/color_tokens.dart';

/// Shows the Smart List editor dialog.
Future<SmartList?> showSmartListEditorDialog(
  BuildContext context, {
  SmartList? initial,
}) {
  return showDialog<SmartList>(
    context: context,
    builder: (context) => _SmartListEditorDialog(initial: initial),
  );
}

class _SmartListEditorDialog extends StatefulWidget {
  const _SmartListEditorDialog({this.initial});

  final SmartList? initial;

  @override
  State<_SmartListEditorDialog> createState() => _SmartListEditorDialogState();
}

class _SmartListEditorDialogState extends State<_SmartListEditorDialog> {
  late SmartList _draft;
  late TextEditingController _nameController;
  late TextEditingController _limitController;
  final FocusNode _limitFocusNode = FocusNode();
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? _SmartListTemplates.blank();
    _draft = initial.copy();
    _nameController = TextEditingController(text: _draft.name);
    _limitController =
        TextEditingController(text: _draft.limit?.toString() ?? '');
    _selectedTemplateId =
        widget.initial == null ? _SmartListTemplates.blankTag : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    _limitFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final densityScale = state.layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final isEditing = widget.initial != null;
    final canSave = _nameController.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Smart List' : 'New Smart List'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name', style: Theme.of(context).textTheme.bodyLarge),
              SizedBox(height: space(8)),
              TextField(
                controller: _nameController,
                onChanged: (value) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Smart List name',
                ),
              ),
              SizedBox(height: space(12)),
              Text('Scope', style: Theme.of(context).textTheme.bodyLarge),
              SizedBox(height: space(8)),
              DropdownButtonFormField<SmartListScope>(
                value: _draft.scope,
                decoration: const InputDecoration(isDense: true),
                onChanged: null,
                items: SmartListScope.values
                    .map(
                      (scope) => DropdownMenuItem(
                        value: scope,
                        child: Text(scope.label),
                      ),
                    )
                    .toList(),
              ),
              SizedBox(height: space(16)),
              if (!isEditing) ...[
                Text('Templates', style: Theme.of(context).textTheme.bodyLarge),
                SizedBox(height: space(8)),
                Wrap(
                  spacing: space(8),
                  runSpacing: space(8),
                  children: _SmartListTemplates.all().map((template) {
                    return ChoiceChip(
                      label: Text(template.label),
                      selected: _selectedTemplateId == template.idTag,
                      onSelected: (_) {
                        setState(() {
                          _selectedTemplateId = template.idTag;
                          _draft = template.apply(
                            _draft,
                            nameOverride: _nameController.text,
                          );
                          _nameController.text = _draft.name;
                          if (!_limitFocusNode.hasFocus) {
                            _limitController.text =
                                _draft.limit?.toString() ?? '';
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: space(16)),
              ],
              Text('Rules', style: Theme.of(context).textTheme.bodyLarge),
              SizedBox(height: space(8)),
              _SmartListGroupEditor(
                group: _draft.group,
                depth: 0,
                onChanged: () => setState(() {}),
              ),
              SizedBox(height: space(16)),
              Text('Sort', style: Theme.of(context).textTheme.bodyLarge),
              SizedBox(height: space(8)),
              _SmartListSortEditor(
                sorts: _draft.sorts,
                onChanged: (next) => setState(() {
                  _draft = _draft.copyWith(sorts: next);
                }),
              ),
              SizedBox(height: space(16)),
              Text('Limit', style: Theme.of(context).textTheme.bodyLarge),
              SizedBox(height: space(8)),
              SizedBox(
                width: 160,
                child: TextField(
                  focusNode: _limitFocusNode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'No limit'),
                  controller: _limitController,
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    setState(() {
                      _draft = _draft.copyWith(
                        limit: parsed == null || parsed <= 0 ? null : parsed,
                      );
                    });
                  },
                ),
              ),
              SizedBox(height: space(8)),
              Text(
                'Limits apply after sorting.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ColorTokens.textSecondary(context, 0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSave
              ? () {
                  final trimmed = _nameController.text.trim();
                  final next = _draft.copyWith(name: trimmed);
                  Navigator.of(context).pop(next);
                }
              : null,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _SmartListGroupEditor extends StatelessWidget {
  const _SmartListGroupEditor({
    required this.group,
    required this.depth,
    required this.onChanged,
    this.isRoot = true,
    this.onRemove,
  });

  final SmartListGroup group;
  final int depth;
  final VoidCallback onChanged;
  final bool isRoot;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final borderColor = ColorTokens.border(context);
    return Container(
      padding: EdgeInsets.all(space(12).clamp(8.0, 16.0)),
      decoration: BoxDecoration(
        color: ColorTokens.cardFill(context, 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Match', style: Theme.of(context).textTheme.bodySmall),
              SizedBox(width: space(8)),
              DropdownButton<SmartListGroupMode>(
                value: group.mode,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  group.mode = value;
                  onChanged();
                },
                items: SmartListGroupMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(mode.label),
                      ),
                    )
                    .toList(),
              ),
              const Spacer(),
              if (!isRoot)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove group',
                  onPressed: onRemove,
                ),
            ],
          ),
          SizedBox(height: space(12)),
          ...group.children.asMap().entries.map((entry) {
            final index = entry.key;
            final node = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: space(8)),
              child: node is SmartListRuleNode
                  ? _SmartListRuleEditor(
                      key: ValueKey(node.rule),
                      rule: node.rule,
                      onRemove: () {
                        group.children.removeAt(index);
                        onChanged();
                      },
                      onChanged: onChanged,
                    )
                  : _SmartListGroupEditor(
                      group: (node as SmartListGroupNode).group,
                      depth: depth + 1,
                      isRoot: false,
                      onChanged: onChanged,
                      onRemove: () {
                        group.children.removeAt(index);
                        onChanged();
                      },
                    ),
            );
          }),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  group.children.add(
                    SmartListRuleNode(
                      rule: SmartListRule(
                        field: SmartListField.title,
                        operatorType: SmartListField.title.operators.first,
                        value: '',
                      ),
                    ),
                  );
                  onChanged();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add rule'),
              ),
              SizedBox(width: space(8)),
              TextButton.icon(
                onPressed: () {
                  group.children.add(
                    SmartListGroupNode(
                      group: SmartListGroup(
                        mode: SmartListGroupMode.all,
                        children: [],
                      ),
                    ),
                  );
                  onChanged();
                },
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add group'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmartListRuleEditor extends StatefulWidget {
  const _SmartListRuleEditor({
    required this.rule,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final SmartListRule rule;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_SmartListRuleEditor> createState() => _SmartListRuleEditorState();
}

class _SmartListRuleEditorState extends State<_SmartListRuleEditor> {
  late TextEditingController _valueController;
  late TextEditingController _value2Controller;
  final FocusNode _valueFocus = FocusNode();
  final FocusNode _value2Focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: widget.rule.value);
    _value2Controller = TextEditingController(text: widget.rule.value2 ?? '');
  }

  @override
  void didUpdateWidget(covariant _SmartListRuleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_valueFocus.hasFocus && widget.rule.value != _valueController.text) {
      _valueController.text = widget.rule.value;
    }
    final nextValue2 = widget.rule.value2 ?? '';
    if (!_value2Focus.hasFocus && nextValue2 != _value2Controller.text) {
      _value2Controller.text = nextValue2;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _value2Controller.dispose();
    _valueFocus.dispose();
    _value2Focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    final rule = widget.rule;
    final operators = rule.field.operators;
    if (!operators.contains(rule.operatorType)) {
      rule.operatorType = operators.first;
    }
    final showValue = rule.field.valueType != SmartListValueType.boolean;
    final showSecondValue = rule.operatorType == SmartListOperator.between;
    final hint = _hintForRule(rule);
    final dropdownStyle = Theme.of(context).textTheme.bodySmall ??
        Theme.of(context).textTheme.bodyMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final fieldDropdown = ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 140),
          child: DropdownButtonFormField<SmartListField>(
            value: rule.field,
            isExpanded: true,
            style: dropdownStyle,
            decoration: const InputDecoration(isDense: true),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              rule.field = value;
              rule.operatorType = value.operators.first;
              rule.value = '';
              rule.value2 = null;
              _valueController.text = '';
              _value2Controller.text = '';
              widget.onChanged();
            },
            items: SmartListField.values
                .map(
                  (field) => DropdownMenuItem(
                    value: field,
                    child: Text(field.label, style: dropdownStyle),
                  ),
                )
                .toList(),
          ),
        );
        final operatorDropdown = ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 140),
          child: DropdownButtonFormField<SmartListOperator>(
            value: rule.operatorType,
            isExpanded: true,
            style: dropdownStyle,
            decoration: const InputDecoration(isDense: true),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              rule.operatorType = value;
              if (value != SmartListOperator.between) {
                rule.value2 = null;
                _value2Controller.text = '';
              }
              widget.onChanged();
            },
            items: operators
                .map(
                  (op) => DropdownMenuItem(
                    value: op,
                    child: Text(op.label, style: dropdownStyle),
                  ),
                )
                .toList(),
          ),
        );
        final valueField = TextField(
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
          ),
          controller: _valueController,
          focusNode: _valueFocus,
          onChanged: (value) {
            rule.value = value;
            widget.onChanged();
          },
        );
        final value2Field = TextField(
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'And',
          ),
          controller: _value2Controller,
          focusNode: _value2Focus,
          onChanged: (value) {
            rule.value2 = value;
            widget.onChanged();
          },
        );
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: fieldDropdown),
                  SizedBox(width: space(8)),
                  Expanded(flex: 3, child: operatorDropdown),
                  SizedBox(width: space(6)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove rule',
                    onPressed: widget.onRemove,
                  ),
                ],
              ),
              if (showValue) ...[
                SizedBox(height: space(8)),
                Row(
                  children: [
                    Expanded(child: valueField),
                    if (showSecondValue) ...[
                      SizedBox(width: space(8)),
                      Expanded(child: value2Field),
                    ],
                  ],
                ),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: fieldDropdown),
            SizedBox(width: space(8)),
            Expanded(flex: 3, child: operatorDropdown),
            if (showValue) ...[
              SizedBox(width: space(8)),
              Expanded(flex: 2, child: valueField),
            ],
            if (showSecondValue) ...[
              SizedBox(width: space(8)),
              Expanded(flex: 2, child: value2Field),
            ],
            SizedBox(width: space(6)),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove rule',
              onPressed: widget.onRemove,
            ),
          ],
        );
      },
    );
  }

  String _hintForRule(SmartListRule rule) {
    switch (rule.field.valueType) {
      case SmartListValueType.text:
        return 'Value';
      case SmartListValueType.number:
        return 'Number';
      case SmartListValueType.duration:
        return 'mm:ss';
      case SmartListValueType.date:
        return rule.operatorType == SmartListOperator.inLast ||
                rule.operatorType == SmartListOperator.notInLast
            ? '30d'
            : 'YYYY-MM-DD';
      case SmartListValueType.boolean:
        return '';
    }
  }
}

class _SmartListSortEditor extends StatelessWidget {
  const _SmartListSortEditor({
    required this.sorts,
    required this.onChanged,
  });

  final List<SmartListSort> sorts;
  final ValueChanged<List<SmartListSort>> onChanged;

  @override
  Widget build(BuildContext context) {
    final densityScale = context.watch<AppState>().layoutDensity.scaleDouble;
    double space(double value) => value * densityScale;
    return Column(
      children: [
        ...sorts.asMap().entries.map((entry) {
          final index = entry.key;
          final sort = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: space(8)),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<SmartListField>(
                    value: sort.field,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final next = List<SmartListSort>.from(sorts);
                      next[index] = sort.copyWith(field: value);
                      onChanged(next);
                    },
                    items: SmartListField.values
                        .map(
                          (field) => DropdownMenuItem(
                            value: field,
                            child: Text(field.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
                SizedBox(width: space(8)),
                Expanded(
                  child: DropdownButtonFormField<SmartListSortDirection>(
                    value: sort.direction,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final next = List<SmartListSort>.from(sorts);
                      next[index] = sort.copyWith(direction: value);
                      onChanged(next);
                    },
                    items: SmartListSortDirection.values
                        .map(
                          (dir) => DropdownMenuItem(
                            value: dir,
                            child: Text(dir == SmartListSortDirection.asc
                                ? 'Asc'
                                : 'Desc'),
                          ),
                        )
                        .toList(),
                  ),
                ),
                SizedBox(width: space(6)),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove sort',
                  onPressed: () {
                    final next = List<SmartListSort>.from(sorts)
                      ..removeAt(index);
                    onChanged(next);
                  },
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            final next = List<SmartListSort>.from(sorts)
              ..add(
                const SmartListSort(
                  field: SmartListField.title,
                  direction: SmartListSortDirection.asc,
                ),
              );
            onChanged(next);
          },
          icon: const Icon(Icons.add),
          label: const Text('Add sort'),
        ),
      ],
    );
  }
}

class _SmartListTemplate {
  const _SmartListTemplate({
    required this.idTag,
    required this.label,
    required this.apply,
  });

  final String idTag;
  final String label;
  final SmartList Function(SmartList draft, {String? nameOverride}) apply;
}

class _SmartListTemplates {
  static const String blankTag = 'template-blank';

  static SmartList blank() => SmartList(
        id: _generateId(),
        name: 'New Smart List',
        scope: SmartListScope.tracks,
        group: SmartListGroup(mode: SmartListGroupMode.all, children: []),
        sorts: const [
          SmartListSort(
            field: SmartListField.title,
            direction: SmartListSortDirection.asc,
          ),
        ],
        showOnHome: false,
      );

  static List<_SmartListTemplate> all() => [
        _SmartListTemplate(
          idTag: blankTag,
          label: 'Blank',
          apply: (draft, {nameOverride}) => draft.copyWith(
            name: nameOverride?.trim().isNotEmpty == true
                ? nameOverride!.trim()
                : draft.name,
            group: SmartListGroup(mode: SmartListGroupMode.all, children: []),
            sorts: const [
              SmartListSort(
                field: SmartListField.title,
                direction: SmartListSortDirection.asc,
              ),
            ],
            limit: null,
            showOnHome: draft.showOnHome,
          ),
        ),
        _SmartListTemplate(
          idTag: 'template-recent',
          label: 'Recently Added',
          apply: (draft, {nameOverride}) => draft.copyWith(
            name: nameOverride?.trim().isNotEmpty == true
                ? nameOverride!.trim()
                : 'Recently Added',
            group: SmartListGroup(
              mode: SmartListGroupMode.all,
              children: [
                SmartListRuleNode(
                  rule: SmartListRule(
                    field: SmartListField.addedAt,
                    operatorType: SmartListOperator.inLast,
                    value: '30d',
                  ),
                ),
              ],
            ),
            sorts: const [
              SmartListSort(
                field: SmartListField.addedAt,
                direction: SmartListSortDirection.desc,
              ),
            ],
            limit: 100,
            showOnHome: draft.showOnHome,
          ),
        ),
        _SmartListTemplate(
          idTag: 'template-unplayed',
          label: 'Unplayed',
          apply: (draft, {nameOverride}) => draft.copyWith(
            name: nameOverride?.trim().isNotEmpty == true
                ? nameOverride!.trim()
                : 'Unplayed',
            group: SmartListGroup(
              mode: SmartListGroupMode.all,
              children: [
                SmartListRuleNode(
                  rule: SmartListRule(
                    field: SmartListField.playCount,
                    operatorType: SmartListOperator.equals,
                    value: '0',
                  ),
                ),
              ],
            ),
            sorts: const [
              SmartListSort(
                field: SmartListField.addedAt,
                direction: SmartListSortDirection.desc,
              ),
            ],
            limit: 200,
            showOnHome: draft.showOnHome,
          ),
        ),
        _SmartListTemplate(
          idTag: 'template-favorites',
          label: 'Favorites',
          apply: (draft, {nameOverride}) => draft.copyWith(
            name: nameOverride?.trim().isNotEmpty == true
                ? nameOverride!.trim()
                : 'Favorites',
            group: SmartListGroup(
              mode: SmartListGroupMode.all,
              children: [
                SmartListRuleNode(
                  rule: SmartListRule(
                    field: SmartListField.isFavorite,
                    operatorType: SmartListOperator.isTrue,
                    value: '',
                  ),
                ),
              ],
            ),
            sorts: const [
              SmartListSort(
                field: SmartListField.title,
                direction: SmartListSortDirection.asc,
              ),
            ],
            showOnHome: draft.showOnHome,
          ),
        ),
        _SmartListTemplate(
          idTag: 'template-offline',
          label: 'Offline',
          apply: (draft, {nameOverride}) => draft.copyWith(
            name: nameOverride?.trim().isNotEmpty == true
                ? nameOverride!.trim()
                : 'Offline',
            group: SmartListGroup(
              mode: SmartListGroupMode.all,
              children: [
                SmartListRuleNode(
                  rule: SmartListRule(
                    field: SmartListField.isDownloaded,
                    operatorType: SmartListOperator.isTrue,
                    value: '',
                  ),
                ),
              ],
            ),
            sorts: const [
              SmartListSort(
                field: SmartListField.title,
                direction: SmartListSortDirection.asc,
              ),
            ],
            showOnHome: draft.showOnHome,
          ),
        ),
      ];

  static String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'smart-$now';
  }
}
