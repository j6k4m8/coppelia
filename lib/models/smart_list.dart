/// Smart List scope definitions.
enum SmartListScope {
  /// Rules apply to tracks.
  tracks,
}

extension SmartListScopeMeta on SmartListScope {
  /// Display label for UI.
  String get label {
    switch (this) {
      case SmartListScope.tracks:
        return 'Tracks';
    }
  }
}

/// How to combine rules inside a group.
enum SmartListGroupMode {
  /// All rules must match.
  all,

  /// Any rule may match.
  any,

  /// No rules may match.
  not,
}

extension SmartListGroupModeMeta on SmartListGroupMode {
  /// Display label for UI.
  String get label {
    switch (this) {
      case SmartListGroupMode.all:
        return 'All';
      case SmartListGroupMode.any:
        return 'Any';
      case SmartListGroupMode.not:
        return 'Not';
    }
  }
}

/// Sort direction for Smart List ordering.
enum SmartListSortDirection {
  /// Sort ascending.
  asc,

  /// Sort descending.
  desc,
}

/// Supported fields for Smart List rules.
enum SmartListField {
  /// Track title.
  title,

  /// Album name.
  album,

  /// Artist name.
  artist,

  /// Genre name.
  genre,

  /// Date added to the library.
  addedAt,

  /// Play count.
  playCount,

  /// Last played date.
  lastPlayedAt,

  /// Track duration.
  duration,

  /// Track favorite state.
  isFavorite,

  /// Offline pin state.
  isDownloaded,

  /// Album favorite state.
  albumIsFavorite,

  /// Artist favorite state.
  artistIsFavorite,
}

/// Operators supported by Smart List rules.
enum SmartListOperator {
  contains,
  doesNotContain,
  equals,
  notEquals,
  startsWith,
  endsWith,
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  between,
  isBefore,
  isAfter,
  isOn,
  inLast,
  notInLast,
  isTrue,
  isFalse,
}

extension SmartListOperatorMeta on SmartListOperator {
  /// Display label for UI.
  String get label {
    switch (this) {
      case SmartListOperator.contains:
        return 'contains';
      case SmartListOperator.doesNotContain:
        return 'does not contain';
      case SmartListOperator.equals:
        return 'equals';
      case SmartListOperator.notEquals:
        return 'not equals';
      case SmartListOperator.startsWith:
        return 'starts with';
      case SmartListOperator.endsWith:
        return 'ends with';
      case SmartListOperator.greaterThan:
        return 'greater than';
      case SmartListOperator.greaterThanOrEqual:
        return 'greater or equal';
      case SmartListOperator.lessThan:
        return 'less than';
      case SmartListOperator.lessThanOrEqual:
        return 'less or equal';
      case SmartListOperator.between:
        return 'between';
      case SmartListOperator.isBefore:
        return 'is before';
      case SmartListOperator.isAfter:
        return 'is after';
      case SmartListOperator.isOn:
        return 'is on';
      case SmartListOperator.inLast:
        return 'in last';
      case SmartListOperator.notInLast:
        return 'not in last';
      case SmartListOperator.isTrue:
        return 'is true';
      case SmartListOperator.isFalse:
        return 'is false';
    }
  }
}

/// Value type for rule fields.
enum SmartListValueType {
  text,
  number,
  date,
  duration,
  boolean,
}

/// Field metadata for UI and parsing.
extension SmartListFieldMeta on SmartListField {
  /// Display label for UI.
  String get label {
    switch (this) {
      case SmartListField.title:
        return 'Title';
      case SmartListField.album:
        return 'Album';
      case SmartListField.artist:
        return 'Artist';
      case SmartListField.genre:
        return 'Genre';
      case SmartListField.addedAt:
        return 'Added date';
      case SmartListField.playCount:
        return 'Play count';
      case SmartListField.lastPlayedAt:
        return 'Last played';
      case SmartListField.duration:
        return 'Duration';
      case SmartListField.isFavorite:
        return 'Track is favorite';
      case SmartListField.isDownloaded:
        return 'Track is downloaded';
      case SmartListField.albumIsFavorite:
        return 'Album is favorite';
      case SmartListField.artistIsFavorite:
        return 'Artist is favorite';
    }
  }

  /// Value type for this field.
  SmartListValueType get valueType {
    switch (this) {
      case SmartListField.title:
      case SmartListField.album:
      case SmartListField.artist:
      case SmartListField.genre:
        return SmartListValueType.text;
      case SmartListField.addedAt:
      case SmartListField.lastPlayedAt:
        return SmartListValueType.date;
      case SmartListField.playCount:
        return SmartListValueType.number;
      case SmartListField.duration:
        return SmartListValueType.duration;
      case SmartListField.isFavorite:
      case SmartListField.isDownloaded:
      case SmartListField.albumIsFavorite:
      case SmartListField.artistIsFavorite:
        return SmartListValueType.boolean;
    }
  }

  /// Operators allowed for this field.
  List<SmartListOperator> get operators {
    switch (valueType) {
      case SmartListValueType.text:
        return const [
          SmartListOperator.contains,
          SmartListOperator.doesNotContain,
          SmartListOperator.equals,
          SmartListOperator.notEquals,
          SmartListOperator.startsWith,
          SmartListOperator.endsWith,
        ];
      case SmartListValueType.number:
      case SmartListValueType.duration:
        return const [
          SmartListOperator.equals,
          SmartListOperator.notEquals,
          SmartListOperator.greaterThan,
          SmartListOperator.greaterThanOrEqual,
          SmartListOperator.lessThan,
          SmartListOperator.lessThanOrEqual,
          SmartListOperator.between,
        ];
      case SmartListValueType.date:
        return const [
          SmartListOperator.isBefore,
          SmartListOperator.isAfter,
          SmartListOperator.isOn,
          SmartListOperator.inLast,
          SmartListOperator.notInLast,
        ];
      case SmartListValueType.boolean:
        return const [
          SmartListOperator.isTrue,
          SmartListOperator.isFalse,
        ];
    }
  }
}

/// Sort options for Smart Lists.
class SmartListSort {
  /// Creates a sort rule.
  const SmartListSort({
    required this.field,
    required this.direction,
  });

  /// Field to sort by.
  final SmartListField field;

  /// Sort direction.
  final SmartListSortDirection direction;

  /// Serializes for persistence.
  Map<String, dynamic> toJson() => {
        'field': field.name,
        'direction': direction.name,
      };

  /// Restores from persisted JSON.
  factory SmartListSort.fromJson(Map<String, dynamic> json) => SmartListSort(
        field: SmartListField.values.firstWhere(
          (field) => field.name == json['field'],
          orElse: () => SmartListField.title,
        ),
        direction: SmartListSortDirection.values.firstWhere(
          (dir) => dir.name == json['direction'],
          orElse: () => SmartListSortDirection.asc,
        ),
      );

  /// Creates a copy with changes.
  SmartListSort copyWith({
    SmartListField? field,
    SmartListSortDirection? direction,
  }) {
    return SmartListSort(
      field: field ?? this.field,
      direction: direction ?? this.direction,
    );
  }
}

/// Rule definition inside a Smart List.
class SmartListRule {
  /// Creates a Smart List rule.
  SmartListRule({
    required this.field,
    required this.operatorType,
    this.value = '',
    this.value2,
  });

  /// Field being tested.
  SmartListField field;

  /// Operator for this rule.
  SmartListOperator operatorType;

  /// Primary value.
  String value;

  /// Secondary value (for between).
  String? value2;

  /// Serializes for persistence.
  Map<String, dynamic> toJson() => {
        'field': field.name,
        'operator': operatorType.name,
        'value': value,
        if (value2 != null) 'value2': value2,
      };

  /// Restores from persisted JSON.
  factory SmartListRule.fromJson(Map<String, dynamic> json) => SmartListRule(
        field: SmartListField.values.firstWhere(
          (field) => field.name == json['field'],
          orElse: () => SmartListField.title,
        ),
        operatorType: SmartListOperator.values.firstWhere(
          (op) => op.name == json['operator'],
          orElse: () => SmartListOperator.contains,
        ),
        value: json['value']?.toString() ?? '',
        value2: json['value2']?.toString(),
      );

  /// Creates a copy with changes.
  SmartListRule copyWith({
    SmartListField? field,
    SmartListOperator? operatorType,
    String? value,
    String? value2,
  }) {
    return SmartListRule(
      field: field ?? this.field,
      operatorType: operatorType ?? this.operatorType,
      value: value ?? this.value,
      value2: value2 ?? this.value2,
    );
  }
}

/// Node inside a Smart List rule tree.
abstract class SmartListNode {
  /// Base constructor for Smart List nodes.
  SmartListNode();

  /// Serializes for persistence.
  Map<String, dynamic> toJson();

  /// Creates a deep copy.
  SmartListNode copy();

  /// Restores a node from persisted JSON.
  factory SmartListNode.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString();
    if (type == 'group') {
      return SmartListGroupNode(
        group: SmartListGroup.fromJson(json),
      );
    }
    return SmartListRuleNode(
      rule: SmartListRule.fromJson(json),
    );
  }
}

/// Rule node in the tree.
class SmartListRuleNode extends SmartListNode {
  /// Creates a rule node.
  SmartListRuleNode({required this.rule});

  /// Rule definition.
  SmartListRule rule;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'rule',
        ...rule.toJson(),
      };

  @override
  SmartListNode copy() => SmartListRuleNode(rule: rule.copyWith());
}

/// Group node in the tree.
class SmartListGroupNode extends SmartListNode {
  /// Creates a group node.
  SmartListGroupNode({required this.group});

  /// Group definition.
  SmartListGroup group;

  @override
  Map<String, dynamic> toJson() => group.toJson();

  @override
  SmartListNode copy() => SmartListGroupNode(group: group.copy());
}

/// Rule grouping node.
class SmartListGroup {
  /// Creates a rule group.
  SmartListGroup({
    required this.mode,
    required this.children,
  });

  /// Group mode.
  SmartListGroupMode mode;

  /// Child rules or groups.
  List<SmartListNode> children;

  /// Serializes for persistence.
  Map<String, dynamic> toJson() => {
        'type': 'group',
        'mode': mode.name,
        'children': children.map((child) => child.toJson()).toList(),
      };

  /// Restores from persisted JSON.
  factory SmartListGroup.fromJson(Map<String, dynamic> json) => SmartListGroup(
        mode: SmartListGroupMode.values.firstWhere(
          (mode) => mode.name == json['mode'],
          orElse: () => SmartListGroupMode.all,
        ),
        children: (json['children'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SmartListNode.fromJson)
            .toList(),
      );

  /// Creates a deep copy.
  SmartListGroup copy() => SmartListGroup(
        mode: mode,
        children: children.map((child) => child.copy()).toList(),
      );
}

/// Smart List definition.
class SmartList {
  /// Creates a Smart List.
  const SmartList({
    required this.id,
    required this.name,
    required this.scope,
    required this.group,
    this.sorts = const [],
    this.limit,
    this.showOnHome = false,
  });

  /// Unique identifier.
  final String id;

  /// Display name.
  final String name;

  /// Scope for list contents.
  final SmartListScope scope;

  /// Root rule group.
  final SmartListGroup group;

  /// Sorting rules.
  final List<SmartListSort> sorts;

  /// Max items to return.
  final int? limit;

  /// Whether this Smart List should appear on Home.
  final bool showOnHome;

  /// Serializes for persistence.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'scope': scope.name,
        'group': group.toJson(),
        'sorts': sorts.map((sort) => sort.toJson()).toList(),
        if (limit != null) 'limit': limit,
        'showOnHome': showOnHome,
      };

  /// Restores from persisted JSON.
  factory SmartList.fromJson(Map<String, dynamic> json) => SmartList(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Untitled Smart List',
        scope: SmartListScope.values.firstWhere(
          (scope) => scope.name == json['scope'],
          orElse: () => SmartListScope.tracks,
        ),
        group: SmartListGroup.fromJson(
          (json['group'] as Map<String, dynamic>? ?? const {}),
        ),
        sorts: (json['sorts'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SmartListSort.fromJson)
            .toList(),
        limit: json['limit'] is num ? (json['limit'] as num).toInt() : null,
        showOnHome: json['showOnHome'] == true,
      );

  /// Creates a copy with changes.
  SmartList copyWith({
    String? id,
    String? name,
    SmartListScope? scope,
    SmartListGroup? group,
    List<SmartListSort>? sorts,
    int? limit,
    bool? showOnHome,
  }) {
    return SmartList(
      id: id ?? this.id,
      name: name ?? this.name,
      scope: scope ?? this.scope,
      group: group ?? this.group,
      sorts: sorts ?? this.sorts,
      limit: limit ?? this.limit,
      showOnHome: showOnHome ?? this.showOnHome,
    );
  }

  /// Creates a deep copy for editing.
  SmartList copy() => SmartList(
        id: id,
        name: name,
        scope: scope,
        group: group.copy(),
        sorts: sorts.map((sort) => sort.copyWith()).toList(),
        limit: limit,
        showOnHome: showOnHome,
      );
}
