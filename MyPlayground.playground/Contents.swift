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
        if self.players.contains(player) == false {
            self.players.append(player)
        }
        
        if self.kills.keys.contains(player) == false {
            self.kills[player] = 0
        }
    }
    
    func advanceKill(player: String, by: Int) {
        self.addPlayer(player: player)
        if let currentKills = self.kills[player] {
            self.kills[player] = currentKills + by
        } else {
            self.kills[player] = by
        }
        
        
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
    let parseKillRegex = "Kill:\\s+\\d+\\s+\\d+\\s+\\d+:\\s+([\\d\\w<>]+)\\s+killed\\s+([\\d\\w<>]+)\\s+by\\s+(MOD_\\w+)"
    
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
        let matches: [String] = regexMatches(pattern: self.parseKillRegex, inString: entry)
        
        guard matches.count == 3 else {
            return game;
        }
        
        game.totalKills += 1
        
        game.addPlayer(player: matches[1])
        
        if matches[0] == "<world>" {
            game.advanceKill(player: matches[1], by: -1)
        } else {
            game.advanceKill(player: matches[0], by: 1)
        }
        
        return game
    }
    
    func killsByReason(entries: [String]) -> [String:Int] {
        var out = [String:Int]()
        for entry in entries {
            let matches = regexMatches(pattern: self.parseKillRegex, inString: entry)
            guard matches.count == 3 else {
                continue
            }
            
            if out.keys.contains(matches[2]) == false {
                out[matches[2]] = 0
            }
            
            let currentKills = out[matches[2]];
            out[matches[2]] = currentKills! + 1;
        }
        
        return out
    }
}

class MainProcess {
    let parser = QuakeLogParser()
    let semaphore = DispatchSemaphore(value: 1)
    func start () {
        if semaphore.wait(timeout: DispatchTime.distantFuture) == .success {
            let url = "https://gist.github.com/alissonsales/01a2ba6d5042464df009725f499e8ba2/raw/a7ca32c40bdb753f8defa0160a583b173459ef7c/games.log"
            self.parser.requestLog(url: url, onSuccess: self.handleSuccess, onFailure: self.handleFailure);
            self.semaphore.wait()
        }
        
    }
    
    func handleSuccess(data: Data) {
        if let stringData = String(data: data, encoding: String.Encoding.utf8) {
            let entries:[String] = stringData.components(separatedBy: "\n")
            parser.parseLog(entries: entries)
            let json = try! JSONSerialization.data(withJSONObject: parser.games, options: .prettyPrinted);
            let out = String(data: json, encoding: String.Encoding.utf8)
            print(out)
            
            print("Kills by means: \(parser.killsByReason(entries: entries))")
            semaphore.signal()
        }
    }
    
    func handleFailure(message: String) {
        print(message)
        semaphore.signal()
    }
}

let process = MainProcess()
process.start()
