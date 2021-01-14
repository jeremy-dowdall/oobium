import 'dart:async';

class ServiceRegistry {
  
  final _services = <Service>[];
  
  void add(Service service) {
    assert(_services.any((s) => s.runtimeType == service.runtimeType) == false);
    service.services.._registry = this;
    _services.add(service);
  }

  T get<T>() => _services.firstWhere((s) => s.runtimeType == T) as T;
 
  void _attach(data) {
    for(var consumer in _services.where((s) => s.consumes == data.runtimeType)) {
      consumer.onAttach(data);
    }
  }
  void _detach(data) {
    for(var consumer in _services.where((s) => s.consumes == data.runtimeType)) {
      consumer.onDetach(data);
    }
  }
  
  Future<void> start() => Future.forEach<Service>(_services, (service) => service.onStart());
  Future<void> stop() => Future.forEach<Service>(_services, (service) => service.onStop());
}

class Services<P> {
  ServiceRegistry _registry;

  void attach(P data) => _registry._attach(data);
  void detach(P data) => _registry._detach(data);

  T get<T>() => _registry.get<T>();
}

abstract class Service<C, P> {
  
  final services = Services<P>();

  Type get consumes => C;
  Type get provides => P;

  void onAttach(C host)    {}
  void onDetach(C host)    {}
  FutureOr<void> onStart() => Future.value();
  FutureOr<void> onStop()  => Future.value();
}
