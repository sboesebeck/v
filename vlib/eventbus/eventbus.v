module eventbus

pub type EventHandlerFn fn(voidptr, voidptr, voidptr)

pub struct Publisher {
mut:
	registry &Registry
}

pub struct Subscriber {
mut:
	registry &Registry
}

struct Registry {
mut:
	events []EventHandler
}

struct EventHandler {
	name string
	handler EventHandlerFn
	receiver voidptr
	once bool
}

pub struct EventBus {
pub mut:
	registry   &Registry
	publisher  &Publisher
pub:
	subscriber &Subscriber
}

pub fn new() &EventBus {
	registry := &Registry{
		events: []
	}
	return &EventBus{
		registry,&Publisher{
			registry},&Subscriber{
			registry}
	}
}

// EventBus Methods
pub fn (eb &EventBus) publish(name string, sender voidptr, args voidptr) {
	mut publisher := eb.publisher
	publisher.publish(name, sender, args)
}

pub fn (eb &EventBus) clear_all() {
	mut publisher := eb.publisher
	publisher.clear_all()
}

pub fn (eb &EventBus) has_subscriber(name string) bool {
	return eb.registry.check_subscriber(name)
}

// Publisher Methods
fn (pb mut Publisher) publish(name string, sender voidptr, args voidptr) {
	for i, event in pb.registry.events {
		if event.name == name {
			if event.once {
				pb.registry.events.delete(i)
			}
			if event.receiver != voidptr(0) {
				event.handler(event.receiver, args, sender)
			} else {
				event.handler(sender, args, voidptr(0))
			}
		}
	}
}

fn (p mut Publisher) clear_all() {
	if p.registry.events.len == 0 {
		return
	}
	for i := p.registry.events.len - 1; i >= 0; i-- {
		p.registry.events.delete(i)
	}
}

// Subscriber Methods
pub fn (s mut Subscriber) subscribe(name string, handler EventHandlerFn) {
	s.registry.events << EventHandler {
		name: name
		handler: handler
		receiver: voidptr(0)
	}
}

pub fn (s mut Subscriber) subscribe_method(name string, handler EventHandlerFn, receiver voidptr) {
	s.registry.events << EventHandler {
		name: name
		handler: handler
		receiver: receiver
	}
}

pub fn (s mut Subscriber) subscribe_once(name string, handler EventHandlerFn) {
	s.registry.events << EventHandler {
		name: name
		handler: handler
		receiver: voidptr(0)
		once: true
	}
}

pub fn (s &Subscriber) is_subscribed(name string) bool {
	return s.registry.check_subscriber(name)
}

pub fn (s mut Subscriber) unsubscribe(name string, handler EventHandlerFn) {
	// v := voidptr(handler)
	for i, event in s.registry.events {
		if event.name == name {
			if event.handler == handler {
				s.registry.events.delete(i)
			}
		}
	}
}

// Registry Methods
fn (r &Registry) check_subscriber(name string) bool {
	for event in r.events {
		if event.name == name {
			return true
		}
	}
	return false
}
