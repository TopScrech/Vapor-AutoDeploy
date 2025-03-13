//
//  to.swift
//  mottzi
//
//  Created by Berken Sayilir on 13.03.2025.
//


import Vapor
import Fluent

// Extension to Model protocol to provide type-erased finder operations
extension Model
{
    // Returns a closure that can find an instance of this model type by ID
    // The type erasure happens by returning a closure that captures the concrete type
    static var typedFinder: (UUID, Database) async throws -> (any Model & Content)?
    {
        return
        { id, db in
            // Use Self to refer to the concrete model type
            return try await Self.find(id, on: db) as? (any Model & Content)
        }
    }
    
    // Returns a closure that can fetch all instances of this model type
    static var typedFindAll: (Database) async throws -> [any Model]
    {
        return
        { db in
            // Use Self to refer to the concrete model type
            return try await Self.query(on: db).all()
        }
    }
}