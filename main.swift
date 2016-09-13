//
//  main.swift
//
//
//  Created by Daniele Bernardi on 9/12/16.
//
//
import Foundation
class MainProcess {
    let parser = QuakeLogParser()
    let semaphore = DispatchSemaphore(value: 1)
    func start () {
        if semaphore.wait(timeout: DispatchTime.distantFuture) == .success {
            // DispatchQueue.main.async { [unowned self] in
                let url = "https://gist.github.com/alissonsales/01a2ba6d5042464df009725f499e8ba2/raw/a7ca32c40bdb753f8defa0160a583b173459ef7c/games.log"
                self.parser.requestLog(url: url, onSuccess: self.handleSuccess, onFailure: self.handleFailure);
                self.semaphore.wait()
            // }
        }

    }

    func handleSuccess(data: Data) {
        if let stringData = String(data: data, encoding: String.Encoding.utf8) {
            let entries:[String] = stringData.components(separatedBy: "\n")
            parser.parseLog(entries: entries)
            let json = try! JSONSerialization.data(withJSONObject: parser.games, options: .prettyPrinted);
            let out = String(data: json, encoding: String.Encoding.utf8)
            print(out)
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