import 'dart:async';

import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  
  final IconData icon;
  final String label;
  final FutureOr<void> Function(BuildContext context) onPressed;
  final TextStyle Function(BuildContext context) textStyle;
  ActionButton({
    this.icon,
    this.label,
    @required this.onPressed,
    this.textStyle
  });
  
  @override
  Widget build(BuildContext _) {
    return Builder(
      builder: (context) {
        final style = (textStyle == null)
          ? Theme.of(context).appBarTheme?.textTheme?.button ?? TextStyle(color: Colors.white)
          : textStyle(context);
        if(icon == null) {
          return FlatButton(
            child: Text(label, style: style),
            onPressed: () => onPressed?.call(context),
          );
        }
        if(label == null) {
          return IconButton(
            icon: Icon(icon, color: style.color,),
            onPressed: () => onPressed?.call(context),
          );
        }
        return FlatButton.icon(
          icon: Icon(icon, color: style.color,),
          label: Text(label, style: style,),
          onPressed: () => onPressed?.call(context)
        );
      }
    );
  } 
}

extension OobiumBuildContextExtensions on BuildContext {

  Future<bool> confirmDelete() async {
    return await showDialog<bool>(
        context: this,
        builder: (context) => AlertDialog(
          title: Text('Permanently Delete?'),
          actions: [
            FlatButton(child: Text('Yes'), onPressed: () => Navigator.pop(context, true),),
            FlatButton(child: Text('No'), onPressed: () => Navigator.pop(context, false),),
          ],
        )
    );
  }

  Future<bool> confirmExit() async {
    return await showDialog<bool>(
        context: this,
        builder: (context) => AlertDialog(
          title: Text('Exit without Saving?'),
          actions: [
            FlatButton(child: Text('Yes'), onPressed: () => Navigator.pop(context, true)),
            FlatButton(child: Text('No'), onPressed: () => Navigator.pop(context, false)),
          ],
        )
    );
  }

  ScaffoldFeatureController showMessage(String message) {
    if(this != null && message != null) {
      return Scaffold.of(this).showSnackBar(SnackBar(content: Text(message)));
    }
    return null;
  }
}
