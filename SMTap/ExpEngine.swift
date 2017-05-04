//
//  ExpEngine.swift
//  Beat
//
//  Created by Tim on 8/18/15.
//  Copyright © 2015 Q. All rights reserved.
//

import Foundation
import AVFoundation

class ExpEngine : NSObject {

	enum TaskType: String {
        case Slow = "slow"
        case Normal = "comfortable"
        case Fast = "fast"
        case Sync = "sync"
		static let allValues = [Slow, Normal, Fast, Sync]
	}
	
	struct Task: CustomStringConvertible {
		var length: Int
		var repeats: Int
		var type: TaskType
		var description: String {
            switch type {
            case .Sync:
                return "\(type.rawValue): \(repeats)x \(length), Seed \(seedID)"
            default:
                return "\(type.rawValue): \(repeats)x \(length)"
            }
        }
		
        var shortChar: String {
            switch type {
            case .Sync:
                return "y"
            default:
                return "\(type.rawValue.characters.first!)"
            }
        }
        
        var seedID: Int
        
        init(length: Int, repeats: Int, type: TaskType, seedID: Int = -1) {
			self.length = length
			self.repeats = repeats
			self.type = type
            self.seedID = seedID
		}
		
		init(inputString:String) {
			//			s-1-12
			let fields = inputString.components(separatedBy: "-")
			
			switch fields[0].lowercased() {
				case "s": type = .Slow
				case "n": type = .Normal  //FIXME: check initial letter used for saving to match what's loaded
				case "f": type = .Fast
                case "x": type = .Sync
			default: type = .Normal
			}
			
            repeats = -1
            length = -1
            seedID = -1
            
            switch type {
            case .Sync:
                seedID = Int(fields[1])!
            default:
                repeats = Int(fields[1])!
                length = Int(fields[2])!
            }
		}
	}
	
	struct Session: CustomStringConvertible {
		var tasks: [Task]
		var date: Date
		
		var description: String {
			var result = ""
			for t in tasks {
				if result.characters.count > 0 { result += " " }
				result += "\(t.shortChar)\(t.repeats)x\(t.length)"
			}
			return result
		}
		
		var dateString: String {
			let dateFormat = DateFormatter.dateFormat(fromTemplate: "EEEE, MMM d", options: 0, locale: Locale.current)
			let dateformatter = DateFormatter()
			dateformatter.dateFormat = dateFormat
			return dateformatter.string(from: date)
		}
	}
	
	struct expRecord {
		var ID: String
		var seq: [[Double]]!
//		var strseq: [String]!
		var fileName: String { return "\(ID)" }
		
		init(ID: String) { self.ID = ID }
	}
	
	enum EventType: String {
		case Up
		case Down
        case Pos
        case Audio
	}
	
// storage:
	var seeds: [[Int]] = [[Int]]()
	
	var taskHistory: [Task] = [Task]() {
		didSet { if taskHistory.count > 10 { taskHistory.removeLast() } }
	}
	var session: [Task] = [Task]()
	var sessionHistory = [Session]()
	
	var showFeedback: Bool = true
	
//	recording stuff
	var currentRecord: expRecord!
 	var currentTaskIndex: Int = 0
	var curTask: Task { return session[currentTaskIndex] }
	
	var length: Int = 0
	var repeats: Int = 0
	
	var isRecording = false
	
	fileprivate var curRecording = [(type: EventType, dur: Double)]()
	fileprivate var curRecordingsAll = [[(type: EventType, dur: Double)]]()
	fileprivate var curPos = [CGPoint]()
	fileprivate var curPosAll = [[CGPoint]]()
	fileprivate var startTime: TimeInterval = 0
	
	override init() {
		super.init()
//        init audio
        audioURL = Bundle.main.url(forResource: "Tone440hz", withExtension: "wav")!
        
        for _ in 0...4 {
            let player: AVAudioPlayer
            do {
                player = try AVAudioPlayer(contentsOf: audioURL)
            } catch {
                print("can't load sound")
                return
            }
            player.delegate = self
            tonePlayers.append(player)
            playerPool.append(player)
        }
        
        
//        load seed file:
        
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)

        let seedfilepath = URL(string: paths[0])?.appendingPathComponent("seeds.csv")
        
//        print(seedfilepath)
        
        var text: String
        do {
            text = try String(contentsOfFile: (seedfilepath?.absoluteString)!)
        } catch _ {
            print(paths[0])
            let newSeq:[Int] = [500,500,500,500,500,500,500]
            seeds.append(newSeq)
            return
        }
        
        //		first split by new line:
        let lines = text.components(separatedBy: CharacterSet.newlines)
        
        let splitlines = lines.map{ $0.components(separatedBy: ",") }
            .filter{ $0.count > 1 }
        seeds = splitlines.map{ $0.map { Int($0)! } }
        seeds = seeds.filter{ $0.count>0 }
        print(seeds)
        

	}
	
	func seqToInterval(_ seq:[(type: EventType, dur: Double)]) -> [Double] {
//		convert up down data into interval format, use ms and lower precision
		var result = [Double]()
		
		var prevDur = seq[0].dur
		for i in 1..<seq.count {
			guard seq[i].type == .Down else { continue }
			
			var interval = (seq[i].dur - prevDur)*1000
			interval = round(100 * interval) / 100
			result.append(interval)
			prevDur = seq[i].dur
		}
		
		return result
	}

//	func seqToString(seq:[(type: EventType, dur: Double)]) -> [String] {
//		var result = [String]()
//		
//		for s in seq {
//			if s.type == .Down {
//				
//				let interval =  round(s.dur*1000*100)/100
//				let name = s.type.rawValue.characters.first
//				result.append("\(name):\(interval)")
//			}
//		}
//		return result
//	}
	
	func intervalToString(_ invSeq: [Double]) -> String {
		return invSeq.map{"\(Int($0)) "}.reduce(""){$0 + $1}
	}
	
//	MARK: - recording methods
	
	func startNewRecord(_ id: String) {
		currentRecord = expRecord(ID: id)
	}
	
	func startRecording() {
		guard !isRecording else { return }
		print("started recording")
		isRecording = true
		curRecording.removeAll(keepingCapacity: true)
		curPos.removeAll(keepingCapacity: true)
		startTime = tonePlayers.first!.deviceCurrentTime
		
		if curTask.type == .Sync {
		//            start playing the sequence too
			self.play(nil)
		}
		
	}
	
	func stopRecording() {
		guard isRecording else {
			return
		}
		print("stoped recording")
		isRecording = false

		guard curRecording.count > 1 else {
			return
		}
		//		save sequence:
		//		normalize time first
		
//		let firstTime = curRecording[0].dur
//		for i in 0..<curRecording.count {
//			var e = curRecording[i]
//			e.dur -= firstTime
//			curRecording[i] = e
//		}
		
//		save to record stash, save to file later
		curRecordingsAll.append(curRecording)
		curRecording.removeAll()
        curPosAll.append(curPos)
        curPos.removeAll()
	}
	
	func tapUp() {
		saveEvent(.Up, time: tonePlayers.first!.deviceCurrentTime)
	}
	
	func tapDown() {
		saveEvent(.Down, time: tonePlayers.first!.deviceCurrentTime)
	}
	
    func tapPos(_ pos: CGPoint) {
		saveEvent(.Pos, time: tonePlayers.first!.deviceCurrentTime)
        curPos.append(pos)
    }
    
	fileprivate func saveEvent(_ type: EventType, time: TimeInterval) {
		guard isRecording else {
			return	// sanity check here, shouldn't really happen
		}
		
		let dur = time - startTime
		curRecording.append((type, dur))
		
//		do filtering right now: disabled
		
//		FIXME!
//		if type == .Up && curRecording.count > 3 {
//			let gap = curRecording[curRecording.count-2].dur - curRecording[curRecording.count-4].dur
//			if gap < 0.05 {
//				print("too fast \(gap)")
//				curRecording.removeLast()
//				curRecording.removeLast()
//			}
//		}
	}
	
    fileprivate func saveToFile(_ seqs:[[(type: EventType, dur: Double)]], posSeqs:[[CGPoint]], outlier:Bool) {
//		NSLog("salva me")
		//		make file name
		let formatter = DateFormatter()
		formatter.dateFormat = "yy.MM.dd-hh.mm.ss"
		var filename = currentRecord.fileName + " " + formatter.string(from: Date())
		filename.append(" "+"\(curTask.shortChar)\(curTask.repeats)x \(curTask.length)")
		
		let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
		let basePath = paths[0]
		
		let baseName = String(describing: basePath) + "/" + filename
		print("saving to \(baseName)")
		
		let fullpath1 = baseName + ".txt"
		let fullpath2 = baseName + ".csv"
		
		var lines = ""
		for (seq, pos) in zip(seqs, posSeqs) {
            var i = 0
			for e in seq {
                if e.type == .Pos {
                    lines += "\(e.type), \(e.dur), \(pos[i].x), \(pos[i].y)\n"
                    i += 1
                } else {
                    lines += "\(e.type), \(e.dur)\n"
                }
			}
			lines += "\n"
 		}
		
		do {
			try lines.write(toFile: fullpath1, atomically: false, encoding: String.Encoding.utf8)
		} catch {
			NSLog("bad:"+filename)
		}
		
//		write interval file
		lines = ""
		for seq in seqs {
			let interval = seqToInterval(seq)
			for inv in interval {
				lines += "\(inv), "
			}
			lines += "\n"
		}
		
		do {
			try lines.write(toFile: fullpath2, atomically: false, encoding: String.Encoding.utf8)
			NSLog(lines)
		} catch {
			NSLog("bad i:"+filename)
		}
	}
	
	func flushRecordToFile(save:Bool = true) {
//		save current record to disk
		if save {
            saveToFile(curRecordingsAll, posSeqs: curPosAll, outlier:false)
		}
		curRecordingsAll.removeAll(keepingCapacity: true)
	}
	
	
//	MARK: - session and tasks
	
    func addTask(_ length: Int, repeats: Int, type: TaskType, seedID: Int = -1) {
		let task = Task(length: length, repeats: repeats, type: type, seedID: seedID)
		session.append(task)

        if type != .Sync {
            addToHistory(task)
        }
	}
	
	func addToHistory(_ task: Task) {
		if !(taskHistory.contains{
			$0.length == task.length && $0.repeats == task.repeats && $0.type == task.type }) {
				taskHistory.insert(task, at: 0)
		}
	}
	
	func saveSession() {
		let saved = sessionHistory.contains {
			guard $0.tasks.count == session.count else { return false }
			
			for i in 0..<$0.tasks.count {
				if $0.tasks[i].length != session[i].length || $0.tasks[i].repeats != session[i].repeats || $0.tasks[i].type != session[i].type {
					return false
				}
			}
			return true
		}
		
		guard !saved else { return }
		
		sessionHistory.append(Session(tasks: session, date: Date()))
	}
    
//    MARK: - playback
    var playingAudio = true
    
    fileprivate var audioURL: URL!
    
    fileprivate var tonePlayers = [AVAudioPlayer]()
    fileprivate var playerPool: [AVAudioPlayer] = []
    
    fileprivate var lastTime: TimeInterval = 0
    
    fileprivate var playTimers = [Timer]()
    
    fileprivate var curBeat: Int = 0
    
    fileprivate var curSeed: [Int] { return seeds[curTask.seedID] }
    
    //	private var curPlaybackSequence = [Double]()
    fileprivate var donePlaying: (()->())! = nil
    fileprivate var failCallback: (()->())! = nil
    
    func play(_ donePlaying: (() -> ())!) {
        guard seeds[curTask.seedID].count > 0 else {
            if donePlaying != nil {
                donePlaying()
            }
            return
        }
        playingAudio = true
        
        playTimers = []
        
        self.donePlaying = donePlaying
        
        curBeat = 0
        print(seeds[curTask.seedID])
        //		print(curSeed.count)
        //		print(seedSeqDownBeats[currentRecord.seedID])
//        var curTime: Double = 0.05
        

        lastTime = tonePlayers.last!.deviceCurrentTime + 0.5
        playTone(lastTime)
        
        let timer = Timer(timeInterval: TimeInterval(curSeed.first!/2000), target: self, selector: #selector(ExpEngine.scheduleTone(_:)), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
        
        let totalTime = Double(curSeed.reduce(0){ ($0 + $1) } / 1000 + 1)
        Timer.scheduledTimer(timeInterval: totalTime, target: self, selector: #selector(ExpEngine.stopPlaying(_:)), userInfo: nil, repeats: false)
    }
    

    
    func scheduleTone(_ timer: Timer) {
        let interval = Double(curSeed[curBeat-1])
        lastTime = lastTime + interval/1000
        
        if curBeat < curSeed.count {
            let nextInterval = Double(curSeed[curBeat])
            let timer = Timer(timeInterval: TimeInterval((nextInterval+interval)/2000), target: self, selector: #selector(ExpEngine.scheduleTone(_:)), userInfo: nil, repeats: false)
            RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
        }
        
        playTone(lastTime)
        
        //		schedule next beat:
        
    }
    
    fileprivate func playTone(_ time:TimeInterval) {
        
//        print("play: \(time), \(curBeat)")
        saveEvent(.Audio, time: time)
        curBeat += 1
        
        //			find available player:
        //		print(playerPool[beatIndex].count)
        
        if playerPool.count > 0 {
            let player = playerPool.removeLast()
            player.play(atTime: time)
            print("success")
            return
        }
        
        //		otherwise just stop a player and use it:
        tonePlayers.last?.stop()
        tonePlayers.last?.play(atTime: time)
    }
    
    func stopPlaying(_ timer: Timer?) {
        print("stopping")
        if donePlaying != nil {
            donePlaying()
        }
        playingAudio = false
    }
    
    func stop() {
        guard playingAudio else { return }
        playingAudio = false
        
        for p in tonePlayers {
            p.stop()
        }
    }
    
}

extension ExpEngine : AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playerPool.append(player)
        player.prepareToPlay()
    }
}

extension Int
{
	static func random(_ range: Range<Int> ) -> Int
	{
		var offset = 0
		
		if range.lowerBound < 0   // allow negative ranges
		{
			offset = abs(range.lowerBound)
		}
		
		let mini = UInt32(range.lowerBound + offset)
		let maxi = UInt32(range.upperBound   + offset)
		
		return Int(mini + arc4random_uniform(maxi - mini)) - offset
	}
}
