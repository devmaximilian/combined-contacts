//
//  ContactStore.swift
//  CombinedContacts
//
//  Created by Maximilian Wendel on 2020-07-22.
//

//  MIT License
//
//  Copyright (c) 2020 Maximilian Wendel
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import Contacts
import Combine

extension CNContactStore {
    public typealias UnifiedContactsPublisher = AnyPublisher<[CNContact], CNError>
    
    /// Returns a publisher that wraps a `CNContactStore` unified contacts fetch request.
    ///
    /// The publisher publishes unified contacts when the request completes, or terminates if the request fails with an error.
    /// - Parameters:
    ///   - predicate: The `NSPredicate` used to match contacts.
    ///   - keys: `CNKeyDescriptor`s specifying the contact fields to retreive.
    /// - Returns: A publisher that wraps a unified contacts fetch request.
    public func unifiedContactsPublisher(
        matching predicate: NSPredicate,
        keysToFetch keys: [String]
    ) -> UnifiedContactsPublisher {
        return Future { completion in
            self.requestAccess(for: .contacts) { (authorized, error) in
                do {
                    guard authorized else {
                        // Attempt to cast error provided by authorization request
                        if let error = error as? CNError {
                            throw error
                        }
                        
                        // Fallback to authorizationDenied
                        throw CNError(.authorizationDenied)
                    }
                    
                    let contacts = try self.unifiedContacts(
                        matching: predicate,
                        keysToFetch: keys as [CNKeyDescriptor]
                    )
                    
                    completion(
                        .success(contacts)
                    )
                } catch {
                    if let error = error as? CNError {
                        completion(
                            .failure(error)
                        )
                    } else {
                        // This should never happen in practice.
                        fatalError("Failed to cast error to CNError")
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
}

extension CNContactStore {
    public typealias UnifiedContactPublisher = AnyPublisher<CNContact, CNError>
    
    /// Returns a publisher that wraps a `CNContactStore` unified contact fetch request.
    ///
    /// The publisher publishes unified contact when the request completes, or terminates if the request fails with an error.
    /// - Parameters:
    ///   - predicate: The `NSPredicate` used to match contacts.
    ///   - keys: `CNKeyDescriptor`s specifying the contact fields to retreive.
    /// - Returns: A publisher that wraps a unified contact fetch request.
    public func unifiedContactPublisher(
        withIdentifier identifier: String,
        keysToFetch keys: [String]
    ) -> UnifiedContactPublisher {
        return Future { completion in
            self.requestAccess(for: .contacts) { (authorized, error) in
                do {
                    guard authorized else {
                        // Attempt to cast error provided by authorization request
                        if let error = error as? CNError {
                            throw error
                        }
                        
                        // Fallback to authorizationDenied
                        throw CNError(.authorizationDenied)
                    }
                    
                    let contact = try self.unifiedContact(
                        withIdentifier: identifier,
                        keysToFetch: keys as [CNKeyDescriptor]
                    )
                    
                    completion(
                        .success(contact)
                    )
                } catch {
                    if let error = error as? CNError {
                        completion(
                            .failure(error)
                        )
                    } else {
                        // This should never happen in practice.
                        fatalError("Failed to cast error to CNError")
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
}

extension CNContactStore {
    public typealias RequestAccessPublisher = AnyPublisher<CNAuthorizationStatus, Error>
    
    /// Returns a publisher that wraps a `CNContactStore` authorization request.
    ///
    /// The publisher publishes an authorization status, or terminates if the request fails with an error.
    /// - Parameter entityType: The `CNEntityType` for which access will be requested.
    /// - Returns: A publisher that wraps a contact store authorization request.
    public func requestAccessPublisher(for entityType: CNEntityType) -> RequestAccessPublisher {
        return Future { completion in
            self.requestAccess(for: entityType) { (_, error) in
                if let error = error {
                    return completion(
                        .failure(error)
                    )
                }
                
                completion(
                    .success(
                        CNContactStore.authorizationStatus(for: entityType)
                    )
                )
            }
        }.eraseToAnyPublisher()
    }
}

extension CNContactStore {
    public typealias SaveRequestPublisher = AnyPublisher<Bool, Error>
    
    private func execute(request: CNSaveRequest) -> SaveRequestPublisher {
        return Future { completion in
            self.requestAccess(for: .contacts) { (authorized, error) in
                do {
                    guard authorized else {
                        throw error ?? CNError(.authorizationDenied)
                    }

                    try self.execute(request)
                    
                    completion(
                        .success(true)
                    )
                } catch {
                    completion(
                        .failure(error)
                    )
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: Save
    
    /// Returns a publisher that wraps a request to add a contact to the contact store.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameters:
    ///   - contact: The new contact to add.
    ///   - identifier: The container identifier to add the contact to. Set to nil for the default container.
    /// - Returns: A publisher that wraps a request to add a new contact to the contact store.
    public func add(_ contact: CNMutableContact, toContainerWithIdentifier identifier: String? = nil) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: identifier)
        return execute(request: saveRequest)
    }
    
    /// Returns a publisher that wraps a request to add a group to the contact store.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameters:
    ///   - group: The new group to add.
    ///   - identifier: The container identifier to add the group to. Set to nil for the default container.
    /// - Returns: A publisher that wraps a request to add a group to the contact store.
    public func save(_ group: CNMutableGroup, toContainerWithIdentifier identifier: String? = nil) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.add(group, toContainerWithIdentifier: identifier)
        return execute(request: saveRequest)
    }
    
    // MARK: Add member
    
    /// Returns a publisher that wraps a request to add a contact to a group.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameters:
    ///   - contact: The member to add to the group.
    ///   - group: The group to add the member to.
    /// - Returns: A publisher that wraps a request to add a contact to a group.
    public func addMember(_ contact: CNContact, to group: CNGroup) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.addMember(contact, to: group)
        return execute(request: saveRequest)
    }
    
    /// Returns a publisher that wraps a request to add a subgroup to a group.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameters:
    ///   - subgroup: The subgroup to add to the group.
    ///   - group: The group to add the subgroup to.
    /// - Returns: A publisher that wraps a request to add a subgroup to a group.
    public func addSubgroup(_ subgroup: CNGroup, to group: CNGroup) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.addSubgroup(subgroup, to: group)
        return execute(request: saveRequest)
    }
    
    // MARK: Update
    
    /// Returns a publisher that wraps a request to update a contact in the contact store.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameter contact: The updated contact.
    /// - Returns: A publisher that wraps a request to update a contact in the contact store.
    public func update(_ contact: CNMutableContact) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.update(contact)
        return execute(request: saveRequest)
    }
    
    /// Returns a publisher that wraps a request to update a group in the contact store.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameter group: The updated group.
    /// - Returns: A publisher that wraps a request to update a group in the contact store.
    public func update(_ group: CNMutableGroup) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.update(group)
        return execute(request: saveRequest)
    }
    
    // MARK: Delete
    
    /// Returns a publisher that wraps a request to delete a contact in the contact store.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameter contact: The contact to delete.
    /// - Returns: A publisher that wraps a request to delete a contact in the contact store.
    public func delete(_ contact: CNMutableContact) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.delete(contact)
        return execute(request: saveRequest)
    }
    
    /// Returns a publisher that wraps a request to delete a group in the contact store.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameter contact: The group to delete.
    /// - Returns: A publisher that wraps a request to delete a group in the contact store.
    public func delete(_ group: CNMutableGroup) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.delete(group)
        return execute(request: saveRequest)
    }
    
    // MARK: Remove member
    
    /// Returns a publisher that wraps a request to remove a contact from a group.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameters:
    ///   - contact: The member to remove from the group.
    ///   - group: The group to remove the member from.
    /// - Returns: A publisher that wraps a request to remove a contact from a group.
    public func removeMember(_ contact: CNContact, to group: CNGroup) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.removeMember(contact, from: group)
        return execute(request: saveRequest)
    }
    
    /// Returns a publisher that wraps a request to remove a subgroup from a group.
    ///
    /// The publisher publishes the request result upon completion, or terminates if the request fails with an error.
    /// - Parameters:
    ///   - contact: The subgroup to remove from the group.
    ///   - group: The group to remove the subgroup from.
    /// - Returns: A publisher that wraps a request to remove a subgroup from a group.
    public func removeSubgroup(_ subgroup: CNGroup, to group: CNGroup) -> SaveRequestPublisher {
        let saveRequest = CNSaveRequest()
        saveRequest.removeSubgroup(subgroup, from: group)
        return execute(request: saveRequest)
    }
}
