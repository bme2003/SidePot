import Foundation

enum Persistence {
    static func documentsURL(_ filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    static func save<T: Encodable>(_ value: T, to filename: String) {
        let url = documentsURL(filename)
        do {
            let data = try JSONEncoder.pretty.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Persistence.save error:", error)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        let url = documentsURL(filename)
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder.iso8601.decode(T.self, from: data)
        } catch {
            return nil
        }
    }
}

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
