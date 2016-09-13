//
//  QuakeLogParserTest.swift
//
//
//  Created by Daniele Bernardi on 9/13/16.
//
//
import Foundation

class TestProcess {
    let parser = QuakeLogParser()
    let semaphore = DispatchSemaphore(value: 1)

    func start () {
        if semaphore.wait(timeout: DispatchTime.distantFuture) == .success {
            self.test(it: "Should retrieve and parse logs", test: testLogParsing)
        }

        self.test(it: "Should match actions", test: testActionMatching)
        self.test(it: "Should parse a kill entry", test: testParseKill)
        print("Test parse kill")
        testParseKill()

    }

    func test(it: String, test:(() -> Void)) {
        print(it)
        test()
        print("")
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
        semaphore.wait()
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
