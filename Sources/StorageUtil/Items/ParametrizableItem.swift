import Foundation

open class ParametrizableItem <Value: Codable, KeyPostfixProviderType: KeyPostfixProvider> {
	internal let accessQueue: DispatchQueue
	internal let logger: Logger<Value>
	
	public let key: String
	public let storage: Storage
	
	public let identificationInfo: IdentificationInfo
	
	public init (
		_ key: String,
		storage: Storage = Global.storage,
		logHandler: LogHandler? = Global.logHandler,
		label: String? = nil,
		file: String = #fileID,
		line: Int = #line
	) {
		let identificationInfo = IdentificationInfo(type: String(describing: Self.self), file: file, line: line, label: label, extra: "Key: \(key)")
		self.identificationInfo = identificationInfo
		
		self.key = key
		self.storage = storage
		
		self.accessQueue = DispatchQueue(label: "\(identificationInfo.typeDescription).\(key).\(identificationInfo.instance).accessQueue")
		self.logger = Logger(
			info: .init(
				keyPrefix: storage.keyPrefix,
				key: key,
				storage: storage.identificationInfo,
				item: identificationInfo
			),
			logHandler: logHandler
		)
	}
}

extension ParametrizableItem {
	@discardableResult
	public func save (_ value: Value, _ keyPostfixProvider: KeyPostfixProviderType) -> Bool {
		accessQueue.sync {
			let keyPostfix = keyPostfixProvider.keyPostfix
			let postfixedKey = KeyBuilder.build(key: key, postfix: keyPostfix)
			
			var details = LogRecord<Value>.Details(operation: "save")
			details.newValue = value
			details.keyPostfix = keyPostfix
			defer { logger.log(details) }
			
			do {
				let oldValue = try storage.save(postfixedKey, value)
				
				details.oldValue = oldValue
				details.existance = oldValue != nil
				
				return true
			} catch {
				details.error = (error as? StorageUtilError) ?? UnexpectedError(error)
				return false
			}
		}
	}
	
	@discardableResult
	public func saveIfNotExist (_ value: Value, _ keyPostfixProvider: KeyPostfixProviderType) -> Bool {
		accessQueue.sync {
			let keyPostfix = keyPostfixProvider.keyPostfix
			let postfixedKey = KeyBuilder.build(key: key, postfix: keyPostfix)
			
			var details = LogRecord<Value>.Details(operation: "save if not exist")
			defer { logger.log(details) }
			
			do {
				if let oldValue = try? storage.load(postfixedKey, Value.self) {
					details.oldValue = oldValue
					details.existance = true
					details.comment = "old value preserved"
					
					return true
				} else {
					details.newValue = value
					
					let oldValue = try storage.save(postfixedKey, value)
					
					details.oldValue = oldValue
					details.existance = oldValue != nil
					details.comment = "value saved"
					
					return true
				}
			} catch {
				details.error = (error as? StorageUtilError) ?? UnexpectedError(error)
				return false
			}
		}
	}
	
	public func load (_ keyPostfixProvider: KeyPostfixProviderType) -> Value? {
		accessQueue.sync {
			let keyPostfix = keyPostfixProvider.keyPostfix
			let postfixedKey = KeyBuilder.build(key: key, postfix: keyPostfix)
			
			var details = LogRecord<Value>.Details(operation: "load")
			details.keyPostfix = keyPostfix
			defer { logger.log(details) }
			
			do {
				let value = try storage.load(postfixedKey, Value.self)
				
				details.oldValue = value
				details.existance = value != nil
				
				return value
			} catch {
				details.existance = false
				details.error = (error as? StorageUtilError) ?? UnexpectedError(error)
				return nil
			}
		}
	}
	
	public func delete (_ keyPostfixProvider: KeyPostfixProviderType) {
		accessQueue.sync {
			let keyPostfix = keyPostfixProvider.keyPostfix
			let postfixedKey = KeyBuilder.build(key: key, postfix: keyPostfix)
			
			var details = LogRecord<Value>.Details(operation: "delete")
			details.keyPostfix = keyPostfix
			defer { logger.log(details) }
			
			do {
				let value = try storage.delete(postfixedKey, Value.self)
				
				details.oldValue = value
				details.existance = value != nil
			} catch {
				details.error = (error as? StorageUtilError) ?? UnexpectedError(error)
			}
		}
	}
	
	public func isExists (_ keyPostfixProvider: KeyPostfixProviderType) -> Bool {
		accessQueue.sync {
			let keyPostfix = keyPostfixProvider.keyPostfix
			let postfixedKey = KeyBuilder.build(key: key, postfix: keyPostfix)
			
			var details = LogRecord<Value>.Details(operation: "is exists")
			details.keyPostfix = keyPostfix
			defer { logger.log(details) }
			
			do {
				let value = try storage.load(postfixedKey, Value.self)
				
				details.oldValue = value
				details.existance = value != nil
				
				return value != nil
			} catch {
				details.existance = false
				details.error = (error as? StorageUtilError) ?? UnexpectedError(error)
				return false
			}
		}
	}
}