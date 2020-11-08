import 'package:oobium_client_gen/src/util/model_field.dart';
import 'package:oobium_client_gen/src/util/scaffolding_model.dart';
import 'package:oobium_common/oobium_common.dart';

class ScaffoldingDetailPageBuilder {

  final ScaffoldingModel model;
  final Iterable<ScaffoldingModel> models;
  ScaffoldingDetailPageBuilder(this.model, this.models);

  bool hasDetailView(String view) => models.any((model) => model.detailView == view);

  String build() => '''
    class ${model.detailView} extends StatelessWidget {

      final Link<${model.type}> ${model.modelVarName};
      ${model.detailView}(this.${model.modelVarName});
      ${model.detailView}.createNew() : ${model.modelVarName} = null;

      @override
      Widget build(BuildContext context) {
        return ChangeNotifierProvider(
          create: (context) => ${model.detailModel}(${model.modelVarName} ?? ${model.type}(context.modelContext).link),
          builder: (context, _) => WillPopScope(
            onWillPop: () async => context.read<${model.detailModel}>().isNotDirty || await context.confirmExit(),
            child: Scaffold(
              appBar: AppBar(
                title: Text('${model.name} Details'),
                actions: [
                  if(context.select<${model.detailModel}, bool>((m) => m.isDirty))
                    ActionButton(
                      icon: Icons.publish,
                      onPressed: (context) async => context.showMessage(await context.read<${model.detailModel}>().save())
                    ),
                  if(context.select<${model.detailModel}, bool>((m) => m.isNotNew))
                    ActionButton(
                      icon: Icons.delete,
                      onPressed: (context) async {
                        if(await context.confirmDelete()) {
                          if(await context.read<${model.detailModel}>().delete()) {
                            Navigator.pop(context);
                          } else {
                            context.showMessage('Failed to delete ${model.name}');
                          }
                        }
                      }
                    ),
                ]
              ),
              body: context.select<${model.detailModel}, bool>((model) => model.isLoading)
                    ? Center(child: Text('loading'))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            ${model.fields.map((field) => buildFieldView(field)).join()}
                          ],
                        )
                      )
            )
          )
        );
      }
    }
    
    class ${model.detailModel} extends ChangeNotifier {
    
      ${model.detailModel}(Link<${model.type}> link) {
        link.resolved().then((value) {
          ${model.modelVarName} = saved = value.model;
          notifyListeners();
        });
      }
      
      ${model.type} saved;
      ${model.type} ${model.modelVarName};
      bool get isLoading => ${model.modelVarName} == null;
      bool get isNotLoading => !isLoading;
      bool get isNew => ${model.modelVarName}?.isNew == true;
      bool get isNotNew => !isNew;
      
      bool get isDirty => isNotLoading && saved.isNotSameAs(${model.modelVarName});
      bool get isNotDirty => !isDirty;
      
      Future<bool> delete() => ${model.modelVarName}.delete();
      
      Future<String> save() async {
        final result = await ${model.modelVarName}.save();
        if(result.isSuccess) {
          ${model.modelVarName} = saved = result.saves[0];
          notifyListeners();
        }
        return result.message;
      }
      
      ${model.fields.map((field) => buildFieldModel(field)).join('\n')}
    }
  ''';

  String buildFieldView(ModelField field) {
    if(field.isString) {
      return '''
        ListTile(
          leading: Text('${field.name.titleized}'),
          title: TextFormField(
            initialValue: context.select<${model.detailModel}, String>((m) => m.${field.name}),
            onChanged: (value) => context.read<${model.detailModel}>().${field.name} = value,
          )
        ),
      ''';
    }
    if(field.isDateTime) {
      return '''
        ListTile(
          leading: Text('${field.name.titleized}'),
          title: Text(context.select<${model.detailModel}, String>((m) => \'\$\{m.${field.name}\}\')),
          trailing: IconButton(
            icon: Icon(Icons.clear),
            onPressed: () => context.read<${model.detailModel}>().${field.name} = null
          ),
          onTap: () async {
            final ${field.name} = context.read<${model.detailModel}>().${field.name} ?? DateTime.now();
            final newValue = await showDatePicker(
                context: context,
                initialDate: ${field.name},
                firstDate: ${field.name}.subtract(Duration(days: 1000)),
                lastDate: ${field.name}.add(Duration(days: 1000))
            );
            if(newValue != null) {
              context.read<${model.detailModel}>().${field.name} = newValue;
            }
          },
        ),
      ''';
    }
    if(field.isHasMany) {
      return '''
        ListTile(
          leading: Text('${field.name.titleized}'),
          title: Text('${field.type}'),
          trailing: Icon(Icons.navigate_next),
          onTap: () {
            final ${field.name} = context.read<${model.detailModel}>().${field.name};
            showModalBottomSheet(
                context: context,
                builder: (context) => ${ScaffoldingModel.getListView(field.linkedModel)}(${field.name})
            );
          }
        ),
      ''';
    }
    if(field.isLink) {
      final linkedDetailView = ScaffoldingModel.getDetailView(field.linkedModel);
      if(hasDetailView(linkedDetailView)) {
        return '''
          ListTile(
            leading: Text('${field.name.titleized}'),
            title: Text(context.select<${model.detailModel}, String>((m) => \'\$\{m.${field.name}\}\')),
            trailing: Icon(Icons.navigate_next),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => $linkedDetailView(context.read<${model.detailModel}>().${field.name})))
          ),
        ''';
      }
    }
    return '''
      ListTile(
        leading: Text('${field.name.titleized}'),
        title: Text(context.select<${model.detailModel}, String>((m) => \'\$\{m.${field.name}\}\')),
      ),
    ''';
  }
  
  String buildFieldModel(ModelField field) {
    if(field.isHasMany) {
      return '''
        ${field.type} get ${field.name} => ${model.modelVarName}.${field.name};
      ''';
    }
    // if(field.isLink && field.typeParameter == field.model.typeParameter) {
    //   return '''
    //   ${field.rawType}<${field.typeParameter}<${field.typeParameter}>> get ${field.name} => ${model.modelVarName}.${field.name};
    //   set ${field.name}(${field.rawType}<${field.typeParameter}<${field.typeParameter}>> value) {
    //     ${model.modelVarName} = ${model.modelVarName}.copyWith(${field.name}: value);
    //     notifyListeners();
    //   }
    // ''';
    // }
    return '''
      ${field.type} get ${field.name} => ${model.modelVarName}.${field.name}${field.defaultValue};
      set ${field.name}(${field.type} value) {
        ${model.modelVarName} = ${model.modelVarName}.copyWith(${field.name}: ${field.copyValue});
        notifyListeners();
      }
    ''';
  }
}

extension _ModelFieldExtensions on ModelField {
  String get copyValue {
    if(isDateTime) return 'value ?? NullValue.dateTime';
    return 'value';
  }
  String get defaultValue {
    if(isString) return "?? ''";
    if(isIterable) return '?? <$type>[]';
    if(isList) return '?? <$type>[]';
    if(isBool) return '?? false';
    if(isInt) return '?? 0';
    if(isNum) return '?? 0';
    if(isDouble) return '?? 0.0';
    // if(isAccess) return 'Access.private';
    // if(isHasMany) return 'HasMany(TODO)';
    return '';
    // throw UnsupportedError('unhandled field type $type');
  }
}
