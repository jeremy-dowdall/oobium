class ModelDefinition {
  final bool isOwnerType;
  const ModelDefinition._(this.isOwnerType);
}
const ModelDefinition owner = ModelDefinition._(true);
const ModelDefinition model = ModelDefinition._(false);

class Resolve {
  const Resolve();
}
const Resolve resolve = Resolve();

class Scaffold {
  const Scaffold();
}
const Scaffold scaffold = Scaffold();