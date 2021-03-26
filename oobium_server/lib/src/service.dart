import 'dart:async';

class ServiceRegistry {
  
  final _services = <Service>[];
  
  void add(Service service) {
    assert(_services.any((s) => s.runtimeType == service.runtimeType) == false);
    service.services._registry = this;
    _services.add(service);
  }

  T get<T>() => _services.firstWhere((s) => s.runtimeType == T, orElse: () => throw Exception('service not found: $T')) as T;
 
  T find<T>() => _services.firstWhere((s) => s.runtimeType == T, orElse: () => null) as T;
 
  Iterable _consumers(data) => _services.where((s) => s.consumes == data.runtimeType);
  
  Future<void> _attach(data) => Future.forEach<Service>(_consumers(data), (c) => c.onAttach(data));
  Future<void> _detach(data) => Future.forEach<Service>(_consumers(data), (c) => c.onDetach(data));
  
  Future<void> start() => Future.forEach<Service>(_services, (service) => service.onStart());
  Future<void> stop() => Future.forEach<Service>(_services, (service) => service.onStop());
}

class Services<P> {
  ServiceRegistry _registry;

  Future<void> attach(P data) => _registry._attach(data);
  Future<void> detach(P data) => _registry._detach(data);

  T get<T>() => _registry.get<T>();
}

abstract class Service<C, P> {
  
  final services = Services<P>();

  Type get consumes => C;
  Type get provides => P;

  FutureOr<void> onAttach(C host) => Future.value();
  FutureOr<void> onDetach(C host) => Future.value();
  FutureOr<void> onStart() => Future.value();
  FutureOr<void> onStop()  => Future.value();
}
