import Foundation



public struct Keychain {	
	public static var settings: Settings = .default
}



public extension Keychain {
	static func save (_ query: [CFString: Any], _ object: Data) throws {
		let logRecord = Logger.Record(.saving(object), query)
		
		do {
			let query = query.merging([kSecValueData: object]){ (current, _) in current }
			
			let status = SecItemAdd(query as CFDictionary, nil)
			guard status != errSecDuplicateItem else { throw Error.existingItemFound }
			guard status == errSecSuccess else { throw Error.savingFailed(status) }
			
			Keychain.Logger.log(logRecord.commit(.saving))
		} catch {
			Keychain.Logger.log(logRecord.commit(.error(error)))
			throw error
		}
	}
	
	static func load (_ query: [CFString: Any]) throws -> AnyObject {
		let logRecord = Logger.Record(.loading, query)
		
		do {
			let loadingAttributes: [CFString: Any] = [
				kSecReturnData: kCFBooleanTrue as Any,
				kSecMatchLimit: kSecMatchLimitOne
			]
			let query = query.merging(loadingAttributes){ (current, _) in current }

			var item: AnyObject?
			let status = SecItemCopyMatching(query as CFDictionary, &item)
			guard status != errSecItemNotFound else { throw Error.itemNotFound }
			guard status == errSecSuccess else { throw Error.loadingFailed(status) }
			guard let unwrappedItem = item else { throw Error.nilItem }
			
			Keychain.Logger.log(logRecord.commit(.loading(unwrappedItem)))
			return unwrappedItem
		} catch {
			Keychain.Logger.log(logRecord.commit(.error(error)))
			throw error
		}
	}
	
	static func delete (_ query: [CFString: Any]) throws {
		let logRecord = Logger.Record(.deletion, query)
		
		do {
			let status = SecItemDelete(query as CFDictionary)
			guard status != errSecItemNotFound else { throw Error.itemNotFound }
			guard status == errSecSuccess else { throw Error.deletingFailed(status) }
			
			Keychain.Logger.log(logRecord.commit(.deletion))
		} catch {
			Keychain.Logger.log(logRecord.commit(.error(error)))
			throw error
		}
	}
	
	static func isExists (_ query: [CFString: Any]) throws -> Bool {
		let logRecord = Logger.Record(.existance, query)
		let isExists: Bool
		
		do {
			let loadingAttributes: [CFString: Any] = [
				kSecReturnData: kCFBooleanTrue as Any,
				kSecMatchLimit: kSecMatchLimitOne
			]
			let query = query.merging(loadingAttributes){ (current, _) in current }
			
			var item: AnyObject?
			let status = SecItemCopyMatching(query as CFDictionary, &item)
			guard status != errSecItemNotFound else { throw Error.itemNotFound }
			guard status == errSecSuccess else { throw Error.existanceCheckFailed(status) }
			guard item != nil else { throw Error.nilItem }
						
			isExists = true
			Keychain.Logger.log(logRecord.commit(.existance(isExists, item)))
			return isExists
		} catch Error.itemNotFound {
			isExists = false
			Keychain.Logger.log(logRecord.commit(.existance(isExists)))
			return isExists
		} catch Error.nilItem {
			isExists = false
			Keychain.Logger.log(logRecord.commit(.existance(isExists)))
			return isExists
		} catch {
			Keychain.Logger.log(logRecord.commit(.error(error)))
			throw error
		}
	}
}



public extension Keychain {
	@discardableResult
	static func clear () -> [Keychain.Class: OSStatus] {
		let logRecord = Logger.Record(.clearing, [:])
		
		var deleteResults = [Keychain.Class: OSStatus]()
		
		for keychainClass in Keychain.Class.allCases {
			let logRecord = Logger.Record(.clearingClass(keychainClass), [:])
			
			let query = [kSecClass: keychainClass.keychainIdentifier]
			let status = SecItemDelete(query as CFDictionary)
			
			Keychain.Logger.log(logRecord.commit(.clearingClass(keychainClass, status)))
			
			deleteResults[keychainClass] = status
		}
		
		Keychain.Logger.log(logRecord.commit(.clearing(deleteResults)))
		
		return deleteResults
	}
	
	static func clear (_ keychainClass: Keychain.Class) throws {
		let logRecord = Logger.Record(.clearingClass(keychainClass), [:])
		
		do {
			let query = [kSecClass: keychainClass.keychainIdentifier]
			let status = SecItemDelete(query as CFDictionary)
			
			guard status == errSecSuccess else { throw Error.classCLearingFailed(keychainClass, status) }
			
			Keychain.Logger.log(logRecord.commit(.clearingClass(keychainClass, status)))
		} catch {
			Keychain.Logger.log(logRecord.commit(.error(error)))
			throw error
		}
	}
}
