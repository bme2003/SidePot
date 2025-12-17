//
//  Persistence.swift
//  SidePot
//
//  Created by Brody England on 12/16/25.
//


import Foundation

enum Persistence {
    static func save<T: Codable>(_ value: T, to filename: String) {
        do {
            let url = try fileURL(for: filename)
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Persistence.save error:", error)
        }
    }

    static func load<T: Codable>(_ type: T.Type, from filename: String) -> T? {
        do {
            let url = try fileURL(for: filename)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Persistence.load error:", error)
            return nil
        }
    }

    private static func fileURL(for filename: String) throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent(filename)
    }
}
