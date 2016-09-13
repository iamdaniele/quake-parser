//
//  main.swift
//
//
//  Created by Daniele Bernardi on 9/12/16.
//
//

import Foundation
import PlaygroundSupport

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

var games = [[String:Any]]();

func main() -> Void {
    PlaygroundPage.current.needsIndefiniteExecution = true
    let url = "https://gist.github.com/alissonsales/01a2ba6d5042464df009725f499e8ba2/raw/a7ca32c40bdb753f8defa0160a583b173459ef7c/games.log"
    requestLog(url: url, onSuccess: handleSuccess, onFailure: handleFailure);
}

func requestLog(url: String, onSuccess:@escaping (Data) -> Void, onFailure:@escaping (String) -> Void) {
    let requestURL:URL = URL(string: url)!
    let request:NSMutableURLRequest = NSMutableURLRequest(url: requestURL)
    let session:URLSession = URLSession.shared
    
    let task = session.dataTask(with: request as URLRequest) { (data, response, error) -> Void in
        let httpResponse = response as! HTTPURLResponse
        let statusCode = httpResponse.statusCode
        
        guard statusCode == 200 else {
            onFailure("Cannot get data. HTTP status: \(statusCode)")
            return
        }
        
        guard data != nil else {
            onFailure("No data received.")
            return
        }
        
        onSuccess(data!)
    }
    
    task.resume()

}

func handleSuccess(data: Data) {
    if let stringData = String(data: data, encoding: String.Encoding.utf8) {
        let entries:[String] = stringData.components(separatedBy: "\n")
        entries.cou
        parseLog(entries: entries)
        let json = try! JSONSerialization.data(withJSONObject: games, options: .prettyPrinted);
        let out = String(data: json, encoding: String.Encoding.utf8)
        print(out)
    }
}

func handleFailure(message: String) {
    print(message)
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
    let action = regexMatches(pattern: "^\\s+\\d+:\\d+\\s+(Kill|InitGame|ShutdownGame)", inString: entry).first
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
    
    if matches[0] == "<world>" {
        game.advanceKill(player: matches[1], by: -1)
    } else {
        game.addPlayer(player: matches[0])
        game.addPlayer(player: matches[1])
        game.advanceKill(player: matches[0], by: 1)
    }
    
    return game
}

main()