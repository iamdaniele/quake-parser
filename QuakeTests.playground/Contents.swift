import Foundation
enum Action: String {
    case Kill = "Kill", InitGame = "InitGame", ShutdownGame = "ShutdownGame"
}

class Game {
    var id: String = ""
    var totalKills: Int = 0
    var players: [String] = [String]()
    var kills: [String:Int] = [String:Int]()
    
    func addPlayer(player: String) {
        if players.contains(player) == false {
            players.append(player)
        }
        
        if kills.keys.contains(player) == false {
            kills[player] = 0
        }
    }
    
    func advanceKill(player: String, by: Int) {
        kills[player]?.advanced(by: by)
    }
    
    func toDictionary() -> [String:Any] {
        let mirror = Mirror(reflecting: self)
        var out = [String:Any]();
        for (_, attr) in mirror.children.enumerated() {
            if let label = attr.label {
                out[label] = attr.value
            }
        }
        
        return out
    }
}

class QuakeLogParser {
    var games = [[String:Any]]();
    
    func requestLog(url: String, onSuccess:@escaping (Data) -> Void, onFailure:@escaping (String) -> Void) {
        let requestURL:URL = URL(string: url)!
        let request:NSMutableURLRequest = NSMutableURLRequest(url: requestURL)
        let session:URLSession = URLSession.shared
        
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
            let httpResponse = response as! HTTPURLResponse
            let statusCode = httpResponse.statusCode
            
            if error != nil {
                if let message = error?.localizedDescription {
                    print (message)
                    onFailure(message)
                    return
                }
                
                onFailure("Unknown error")
            }
            
            switch statusCode {
            case 200:
                guard data != nil else {
                    onFailure("No data received")
                    return
                }
                
                onSuccess(data!)
                break
                
            default:
                onFailure("Cannot get data. HTTP status: \(statusCode)")
                break
            }
        }
        
        task.resume()
        
    }
    
    func parseLog(entries:[String]) {
        var i = 1
        var game = Game()
        for entry in entries {
            if let action = parseAction(entry: entry) {
                switch action {
                case Action.Kill:
                    game = parseKill(entry: entry, game: game)
                    break
                    
                case Action.InitGame:
                    // Assuming InitGame events will always precede a ShutdownGame
                    game = Game()
                    game.id = "game_\(i)"
                    break
                    
                case Action.ShutdownGame:
                    games.append(game.toDictionary())
                    i += 1
                    break
                }
            }
        }
    }
    
    func parseAction(entry: String) -> Action? {
        let action = regexMatches(pattern: "^\\s*\\d+:\\d+\\s+(Kill|InitGame|ShutdownGame)", inString: entry).first
        guard action != nil else {
            return nil
        }
        
        return Action(rawValue: action!)
    }
    
    func regexMatches(pattern: String, inString: String) -> [String] {
        var out = [String]();
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex.matches(in: inString, options: [], range: NSRange(location: 0, length: inString.utf8.count))
            
            for match in matches {
                for i in 1..<match.numberOfRanges {
                    let range = match.rangeAt(i)
                    let stringRange = inString.index(inString.startIndex, offsetBy: range.location) ..< inString.index(inString.startIndex, offsetBy: range.location + range.length)
                    
                    out.append(inString.substring(with: stringRange))
                }
            }
            return out
        } catch {
            return out
        }
    }
    
    func parseKill(entry: String, game: Game) -> Game {
        let matches: [String] = regexMatches(pattern: "Kill:\\s+\\d+\\s+\\d+\\s+\\d+:\\s+([\\d\\w<>]+)\\s+killed\\s+([\\d\\w<>]+)\\s+by\\s+(MOD_\\w+)", inString: entry)
        
        guard matches.count == 3 else {
            return game;
        }
        
        game.totalKills += 1

        game.addPlayer(player: matches[1])

        if matches[0] == "<world>" {
            game.advanceKill(player: matches[1], by: -1)
        } else {
            game.addPlayer(player: matches[0])
            game.advanceKill(player: matches[0], by: 1)
        }
        
        return game
    }
}

class TestProcess {
    let parser = QuakeLogParser()
    let semaphore = DispatchSemaphore(value: 1)
    
    func start () {

        if semaphore.wait(timeout: DispatchTime.distantFuture) == .success {
            self.test(it: "Should retrieve and parse logs", test: testLogParsing)
            semaphore.wait()
        }

        self.test(it: "Should match actions", test: testActionMatching)
        self.test(it: "Should parse a kill entry", test: testParseKill)
        print("Test parse kill")
        testParseKill()
        
    }
    
    func test(it: String, test:(() -> Void)) {
        print(it)
        test()
        print("\n")
    }

    func ok(cond: Bool, msg: String) -> Void {
        if (cond == true) {
            print("\t✔ \(msg)")
        } else {
            print("\t𐄂 \(msg)")
            print("Exiting because the last test failed.")
            exit(1)
        }
    }

    func testLogParsing() {
        // Test success
        let url = "https://gist.github.com/alissonsales/01a2ba6d5042464df009725f499e8ba2/raw/a7ca32c40bdb753f8defa0160a583b173459ef7c/games.log"
        self.parser.requestLog(url: url, onSuccess: { (data) in
            if let responseString = String(data: data, encoding: String.Encoding.utf8) {
                let entries = responseString.components(separatedBy: "\n")
                self.ok(cond: entries.count > 0, msg: "Log entries found")
            }
            self.semaphore.signal()
            
            }, onFailure: { (message) in
                self.ok(cond: false, msg: "Error: \(message)")
                self.semaphore.signal()
        })
    }
    
    func testActionMatching() {
        let killEntry = "20:54 Kill: 1022 2 22: <world> killed Isgalamido by MOD_TRIGGER_HURT"
        self.ok(cond: parser.parseAction(entry: killEntry)?.rawValue == Action.Kill.rawValue, msg: "Parsed kill log entry")
        
        let initGameEntry = "20:37 InitGame: \\sv_floodProtect\\1\\sv_maxPing\\0\\sv_minPing\\0\\sv_maxRate\\10000\\sv_minRate\\0\\sv_hostname\\Code Miner Server\\g_gametype\\0\\sv"
        self.ok(cond: parser.parseAction(entry: initGameEntry)?.rawValue == Action.InitGame.rawValue, msg: "Parsed InitGame log entry")
        
        let shutdownGameEntry = " 12:13 ShutdownGame:"
        self.ok(cond: parser.parseAction(entry: shutdownGameEntry)?.rawValue == Action.ShutdownGame.rawValue, msg: "Parsed ShutdownGame log entry")
        
        let invalidEntry = " 12:34 This line should not match any actions."
        self.ok(cond: parser.parseAction(entry: invalidEntry) == nil, msg: "Unsupported actions are discarded")
    }
    
    func testParseKill() {
        let validKillEntry = "20:54 Kill: 1022 2 22: <world> killed Isgalamido by MOD_TRIGGER_HURT"
        var game = Game()
        game = parser.parseKill(entry: validKillEntry, game: game)
        self.ok(cond: game.totalKills == 1, msg: "Found expected number of total kills")
        self.ok(cond: game.players.contains("<world>") == false, msg: "<world> is not listed as a player")
        self.ok(cond: game.players.contains("Isgalamido"), msg: "Killed player found")
    }
}

let process = TestProcess()
process.start()
