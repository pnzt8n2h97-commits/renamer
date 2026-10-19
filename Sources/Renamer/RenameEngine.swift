import Foundation

enum CaseMode: String, CaseIterable, Identifiable {
    case unchanged = "Unchanged"
    case lower = "lowercase"
    case upper = "UPPERCASE"
    case title = "Title Case"
    var id: String { rawValue }
}

enum NumberPosition: String, CaseIterable, Identifiable {
    case before = "Before name"
    case after = "After name"
    var id: String { rawValue }
}

struct RenameRules: Equatable {
    var find = ""
    var replace = ""
    var useRegex = false
    var caseSensitive = false

    var caseMode: CaseMode = .unchanged
    var lowercaseExtension = false

    var prefix = ""
    var suffix = ""

    var numbering = false
    var start = 1
    var step = 1
    var padding = 2
    var separator = "_"
    var numberPosition: NumberPosition = .after
}

struct RenameItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var newName: String = ""
    var problem: String?

    var originalName: String { url.lastPathComponent }
    var changed: Bool { newName != originalName }
}

struct RenameRecord {
    let from: URL
    let to: URL
}

enum RenameEngine {
    /// Compute the new name for a file at the given position in the list.
    static func newName(for url: URL, index: Int, rules: RenameRules) -> String {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let ext = isDir ? "" : url.pathExtension
        var base = isDir ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent

        if !rules.find.isEmpty {
            var options: String.CompareOptions = []
            if !rules.caseSensitive { options.insert(.caseInsensitive) }
            if rules.useRegex {
                options.insert(.regularExpression)
                base = base.replacingOccurrences(of: rules.find, with: rules.replace, options: options)
            } else {
                base = base.replacingOccurrences(of: rules.find, with: rules.replace, options: options)
            }
        }

        switch rules.caseMode {
        case .unchanged: break
        case .lower: base = base.lowercased()
        case .upper: base = base.uppercased()
        case .title: base = base.capitalized
        }

        base = rules.prefix + base + rules.suffix

        if rules.numbering {
            let n = rules.start + index * rules.step
            let digits = String(n)
            let padded = String(repeating: "0", count: max(0, rules.padding - digits.count)) + digits
            switch rules.numberPosition {
            case .before: base = padded + rules.separator + base
            case .after: base = base + rules.separator + padded
            }
        }

        var finalExt = ext
        if rules.lowercaseExtension { finalExt = finalExt.lowercased() }
        return finalExt.isEmpty ? base : base + "." + finalExt
    }

    /// Recompute names and flag problems (empty, illegal, duplicate, or colliding with an existing file).
    static func preview(items: [RenameItem], rules: RenameRules) -> [RenameItem] {
        var result = items
        for i in result.indices {
            result[i].newName = newName(for: result[i].url, index: i, rules: rules)
            result[i].problem = nil
        }

        let moving = Set(result.map { $0.url.standardizedFileURL.path })
        var seen: [String: Int] = [:]
        for i in result.indices {
            let item = result[i]
            guard item.changed else { continue }
            let name = item.newName
            if name.isEmpty || name == "." || name == ".." {
                result[i].problem = "Empty name"
                continue
            }
            if name.contains("/") || name.contains(":") {
                result[i].problem = "Illegal character"
                continue
            }
            let target = item.url.deletingLastPathComponent().appendingPathComponent(name).standardizedFileURL
            let key = target.path.lowercased()
            if seen[key] != nil {
                result[i].problem = "Duplicate name"
                continue
            }
            seen[key] = i
            if FileManager.default.fileExists(atPath: target.path), !moving.contains(target.path) {
                result[i].problem = "File already exists"
            }
        }
        return result
    }

    /// Apply the renames. Uses temporary names first so swaps and chains (a→b, b→a) work.
    /// Returns the records of what was renamed so it can be undone.
    static func apply(items: [RenameItem]) throws -> [RenameRecord] {
        let fm = FileManager.default
        let work = items.filter { $0.changed && $0.problem == nil }
        var staged: [(temp: URL, final: URL, original: URL)] = []
        var done: [RenameRecord] = []

        do {
            for item in work {
                let dir = item.url.deletingLastPathComponent()
                let temp = dir.appendingPathComponent(".renamer-\(UUID().uuidString)")
                try fm.moveItem(at: item.url, to: temp)
                staged.append((temp, dir.appendingPathComponent(item.newName), item.url))
            }
            for s in staged {
                try fm.moveItem(at: s.temp, to: s.final)
                done.append(RenameRecord(from: s.original, to: s.final))
            }
        } catch {
            // Roll back everything we touched so the user is never left with half-renamed files.
            let finished = Set(done.map { $0.to })
            for s in staged {
                if finished.contains(s.final) {
                    try? fm.moveItem(at: s.final, to: s.original)
                } else if fm.fileExists(atPath: s.temp.path) {
                    try? fm.moveItem(at: s.temp, to: s.original)
                }
            }
            throw error
        }
        return done
    }

    static func undo(_ records: [RenameRecord]) throws {
        let fm = FileManager.default
        var staged: [(temp: URL, original: URL)] = []
        for r in records {
            let temp = r.to.deletingLastPathComponent().appendingPathComponent(".renamer-\(UUID().uuidString)")
            try fm.moveItem(at: r.to, to: temp)
            staged.append((temp, r.from))
        }
        for s in staged { try fm.moveItem(at: s.temp, to: s.original) }
    }
}
