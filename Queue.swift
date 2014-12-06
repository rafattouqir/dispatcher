
import Foundation

/// Both serial and concurrent Queues do not guarantee the same Thread is used every time.
/// An exception is made for the main Queue, which always uses the main Thread.
public class Queue {

  // MARK: Public

  /// This can only be set if this Queue is serial and created by you.
  public var priority: Priority {
    willSet {
      assert(!isGlobal && !isMain && isSerial)
    }
    didSet {
      var target: Queue!
      switch priority {
        case .Main:       target = gcd.main
        case .High:       target = gcd.high
        case .Normal:     target = gcd
        case .Low:        target = gcd.low
        case .Background: target = gcd.background
      }
      dispatch_set_target_queue(wrapped, target.wrapped)
    }
  }

  /// If `true`, this Queue always executes one block at a time.
  public let isSerial: Bool

  public var isCurrent: Bool { return dispatch_get_specific(&kQueueCurrentKey) == getMutablePointer(self) }

  /// If `true`, this Queue wraps around the main UI queue.
  public var isMain: Bool { return self === gcd.main }

  /// If `true`, this Queue wraps around one of Apple's built-in dispatch queues.
  public let isGlobal: Bool

  /// Calls the callback asynchronously on this queue.
  public func async (callback: Void -> Void) {
    dispatch_async(wrapped) { callback() }
  }

  /// If this queue is the current queue, the callback is called immediately.
  /// Else, the callback is called synchronously on this queue.
  public func sync (callback: Void -> Void) {
    isCurrent ? callback() : dispatch_sync(wrapped, { callback() })
  }

  /// If this queue is the current queue, the callback is called immediately.
  /// Else, the callback is called asynchronously on this queue.
  public func csync (callback: Void -> Void) {
    isCurrent ? callback() : async(callback)
  }

  public func suspend () {
    dispatch_suspend(self.wrapped)
  }

  public func resume () {
    dispatch_resume(self.wrapped)
  }

  public func barrier () {
    assert(!isSerial)
    fatalError("Unimplemented.")
  }

  public let wrapped: dispatch_queue_t

  public enum Priority : dispatch_queue_priority_t {
    case Background // Least important
    case Low
    case Normal
    case High
    case Main // Most important
  }



  // MARK: Internal

  /// Initializes the main queue.
  init () {
    isSerial = true
    isGlobal = false
    priority = .Main
    wrapped = dispatch_get_main_queue()

    _register()
  }

  /// Initializes one of Apple's global queues.
  init (_ priority: dispatch_queue_priority_t) {
    isSerial = false
    isGlobal = true
    wrapped = dispatch_get_global_queue(priority, 0)

    switch priority {
      case DISPATCH_QUEUE_PRIORITY_LOW:        self.priority = .Low
      case DISPATCH_QUEUE_PRIORITY_HIGH:       self.priority = .High
      case DISPATCH_QUEUE_PRIORITY_DEFAULT:    self.priority = .Normal
      case DISPATCH_QUEUE_PRIORITY_BACKGROUND: self.priority = .Background
      default: fatalError("invalid priority")
    }

    _register()
  }

  /// Initializes a custom queue.
  init (_ serial: Bool) {
    isSerial = serial
    isGlobal = false
    priority = .Normal
    wrapped = dispatch_queue_create(nil, serial ? DISPATCH_QUEUE_SERIAL : DISPATCH_QUEUE_CONCURRENT)

    _register()
  }

  

  // MARK: Private

  private func _register () {
    dispatch_queue_set_specific(wrapped, &kQueueCurrentKey, getMutablePointer(self), nil)
  }
}

var kQueueCurrentKey = 0

func getMutablePointer (object: AnyObject) -> UnsafeMutablePointer<Void> {
  return UnsafeMutablePointer<Void>(bitPattern: Word(ObjectIdentifier(object).uintValue()))
}