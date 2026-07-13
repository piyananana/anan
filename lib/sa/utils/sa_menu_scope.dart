import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sa_menu.dart';
import '../services/sa_language_provider.dart';

/// Injects the active [Menu] into the widget tree so child screens can read
/// their language-aware title without needing a constructor parameter.
class MenuScope extends InheritedWidget {
  final Menu menu;

  const MenuScope({super.key, required this.menu, required super.child});

  static Menu? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MenuScope>()?.menu;

  @override
  bool updateShouldNotify(MenuScope oldWidget) => oldWidget.menu != menu;
}

/// Displays the current menu name in the active language.
/// Place this as the [AppBar.title] in any screen that is opened from the menu tree.
/// Falls back to [fallback] when no [MenuScope] ancestor is found.
class MenuTitle extends StatelessWidget {
  final String? fallback;
  const MenuTitle({super.key, this.fallback});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (ctx, lang, _) {
        final menu = MenuScope.of(ctx);
        if (menu == null) return Text(fallback ?? '');
        final name = lang.isEnglish && menu.menuNameEn.isNotEmpty
            ? menu.menuNameEn
            : menu.menuName;
        return Text(name);
      },
    );
  }
}
