import 'package:flutter/material.dart';

/// Navigation state management class
class NavigationState extends ChangeNotifier {
  // Current selected index in bottom navigation
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  // Selection mode state
  bool _isSelectionMode = false;
  bool get isSelectionMode => _isSelectionMode;

  // Selected items tracking
  final Set<String> _selectedItems = {};
  Set<String> get selectedItems => _selectedItems;

  // Navigation methods
  void setIndex(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      // Exit selection mode when changing pages
      if (_isSelectionMode) toggleSelectionMode();
      notifyListeners();
    }
  }

  // Selection mode methods
  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) _selectedItems.clear();
    notifyListeners();
  }

  void toggleItemSelection(String itemId) {
    if (_selectedItems.contains(itemId)) {
      _selectedItems.remove(itemId);
    } else {
      _selectedItems.add(itemId);
    }
    notifyListeners();
  }

  void selectAll(List<String> items) {
    _selectedItems.addAll(items);
    notifyListeners();
  }

  void clearSelection() {
    _selectedItems.clear();
    notifyListeners();
  }

  // Navigation state reset
  void reset() {
    _selectedIndex = 0;
    _isSelectionMode = false;
    _selectedItems.clear();
    notifyListeners();
  }
}
