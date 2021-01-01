import 'dart:async';

class ServiceRegistry {
  
  final _services = <Type, Service>{};
  final _listeners = <Type, List<Type>>{};
  
  void add(Service service) {
    final st = service.runtimeType; // eg: DataService extends Service<AuthService> (DS attaches/listens to AS)
    final ht = service.hostType;
    assert(ht != null);
    assert(!_services.containsKey(st));
    service.services.._registry = this.._service = service;
    _services[st] = service;
    _listeners.putIfAbsent(ht, () => <Type>[]).add(st);
  }
  
  T get<T extends Service>() => _services[T];
 
  void _attach(Service service) {
    if(_listeners.containsKey(service.runtimeType)) {
      for(var listener in _listeners[service.runtimeType]) {
        _services[listener].onAttach(service);
      }
    }
  }
  void _detach(Service service) {
    if(_listeners.containsKey(service.runtimeType)) {
      for(var listener in _listeners[service.runtimeType]) {
        _services[listener].onDetach(service);
      }
    }
  }
  
  Future<void> start() => Future.forEach<Service>(_services.values, (service) => service.onStart());
  Future<void> stop() => Future.forEach<Service>(_services.values, (service) => service.onStop());
}

class Services {
  Service _service;
  ServiceRegistry _registry;

  void attach() => _registry._attach(_service);
  void detach() => _registry._detach(_service);
  T get<T extends Service>() => _registry.get<T>();
}

abstract class Service<H> {
  
  final services = Services();
  Type get hostType => H;

  void onAttach(H host)    {}
  void onDetach(H host)    {}
  FutureOr<void> onStart() => Future.value();
  FutureOr<void> onStop()  => Future.value();

}
