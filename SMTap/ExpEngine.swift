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
			let fields = inputString.componentsSeparatedByString("-")
			
			switch fields[0].lowercaseString {
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
		var date: NSDate
		
		var description: String {
			var result = ""
			for t in tasks {
				if result.characters.count > 0 { result += " " }
				result += "\(t.shortChar)\(t.repeats)x\(t.length)"
			}
			return result
		}
		
		var dateString: String {
			let dateFormat = NSDateFormatter.dateFormatFromTemplate("EEEE, MMM d", options: 0, locale: NSLocale.currentLocale())
			let dateformatter = NSDateFormatter()
			dateformatter.dateFormat = dateFormat
			return dateformatter.stringFromDate(date)
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
	
	private var curRecording = [(type: EventType, dur: Double)]()
	private var curRecordingsAll = [[(type: EventType, dur: Double)]]()
	private var curPos = [CGPoint]()
	private var curPosAll = [[CGPoint]]()
	private var startTime: NSTimeInterval = 0
	
	override init() {
		super.init()
//        init audio
        audioURL = NSBundle.mainBundle().URLForResource("Tone440hz", withExtension: "wav")!
        
        for _ in 0...1 {
            let player: AVAudioPlayer
            do {
                player = try AVAudioPlayer(contentsOfURL: audioURL)
            } catch {
                print("can't load sound")
                return
            }
            player.delegate = self
            tonePlayers.append(player)
            playerPool.append(player)
        }
        
        
//        load seed file:
        
        let paths:NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
        
        let seedfilepath = basePath.stringByAppendingPathComponent("seeds.csv")
        
//        print(seedfilepath)
        
        var text: String
        do {
            text = try String(contentsOfFile: seedfilepath)
        } catch _ {
            print(basePath)
            let newSeq:[Int] = [500,500,500,500,500,500,500]
            seeds.append(newSeq)
            return
        }
        
        //		first split by new line:
        let lines = text.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
        
        let splitlines = lines.map{ $0.componentsSeparatedByString(",") }
            .filter{ $0.count > 1 }
        seeds = splitlines.map{ $0.map { Int($0)! } }
        seeds = seeds.filter{ $0.count>0 }
        print(seeds)
        

	}
	
	func seqToInterval(seq:[(type: EventType, dur: Double)]) -> [Double] {
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
	
	func intervalToString(invSeq: [Double]) -> String {
		return invSeq.map{"\(Int($0)) "}.reduce(""){$0 + $1}
	}
	
//	MARK: - recording methods
	
	func startNewRecord(id: String) {
		currentRecord = expRecord(ID: id)
	}
	
	func startRecording() {
		guard !isRecording else { return }
		print("started recording")
		isRecording = true
		curRecording.removeAll(keepCapacity: true)
		curPos.removeAll(keepCapacity: true)
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
	
    func tapPos(pos: CGPoint) {
		saveEvent(.Pos, time: tonePlayers.first!.deviceCurrentTime)
        curPos.append(pos)
    }
    
	private func saveEvent(type: EventType, time: NSTimeInterval) {
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
	
    private func saveToFile(seqs:[[(type: EventType, dur: Double)]], posSeqs:[[CGPoint]], outlier:Bool) {
//		NSLog("salva me")
		//		make file name
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yy.MM.dd-hh.mm.ss"
		var filename = currentRecord.fileName + " " + formatter.stringFromDate(NSDate())
		filename.appendContentsOf(" "+"\(curTask.shortChar)\(curTask.repeats)x \(curTask.length)")
		
		let paths:NSArray = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
		let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
		
		let baseName = String(basePath) + "/" + filename
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
			try lines.writeToFile(fullpath1, atomically: false, encoding: NSUTF8StringEncoding)
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
			try lines.writeToFile(fullpath2, atomically: false, encoding: NSUTF8StringEncoding)
			NSLog(lines)
		} catch {
			NSLog("bad i:"+filename)
		}
	}
	
	func flushRecordToFile(save save:Bool = true) {
//		save current record to disk
		if save {
            saveToFile(curRecordingsAll, posSeqs: curPosAll, outlier:false)
		}
		curRecordingsAll.removeAll(keepCapacity: true)
	}
	
	
//	MARK: - session and tasks
	
    func addTask(length: Int, repeats: Int, type: TaskType, seedID: Int = -1) {
		let task = Task(length: length, repeats: repeats, type: type, seedID: seedID)
		session.append(task)

        if type != .Sync {
            addToHistory(task)
        }
	}
	
	func addToHistory(task: Task) {
		if !(taskHistory.contains{
			$0.length == task.length && $0.repeats == task.repeats && $0.type == task.type }) {
				taskHistory.insert(task, atIndex: 0)
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
		
		sessionHistory.append(Session(tasks: session, date: NSDate()))
	}
    
//    MARK: - playback
    var playingAudio = true
    
    private var audioURL: NSURL!
    
    private var tonePlayers = [AVAudioPlayer]()
    
    private var playTimers = [NSTimer]()
    
    private var curBeat: Int = 0
    
    private var curSeed: [Int] { return seeds[curTask.seedID] }
    
    //	private var curPlaybackSequence = [Double]()
    private var donePlaying: (()->())! = nil
    private var failCallback: (()->())! = nil
    
    func play(donePlaying: (() -> ())!) {
        guard seeds[curTask.seedID].count > 0 else {
            if donePlaying != nil {
                donePlaying()
            }
            return
        }
        
        playTimers = []
        
        self.donePlaying = donePlaying
        
        curBeat = 0
        print(seeds[curTask.seedID])
        //		print(curSeed.count)
        //		print(seedSeqDownBeats[currentRecord.seedID])
//        var curTime: Double = 0.05
        

        lastTime = tonePlayers.last!.deviceCurrentTime + 0.5
        playTone(lastTime)
        
        let timer = NSTimer(timeInterval: NSTimeInterval(curSeed.first!/2000), target: self, selector: "scheduleTone:", userInfo: nil, repeats: false)
        NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSRunLoopCommonModes)
        
        let totalTime = Double(curSeed.reduce(0){ ($0 + $1) } / 1000 + 1)
        NSTimer.scheduledTimerWithTimeInterval(totalTime, target: self, selector: "stopPlaying:", userInfo: nil, repeats: false)
    }
    
    private var lastTime: NSTimeInterval = 0
    private var playerPool: [AVAudioPlayer] = []
    
    func scheduleTone(timer: NSTimer) {
        let interval = Double(curSeed[curBeat-1])
        lastTime = lastTime + interval/1000
        
        if curBeat < curSeed.count {
            let nextInterval = Double(curSeed[curBeat])
            let timer = NSTimer(timeInterval: NSTimeInterval((nextInterval+interval)/2000), target: self, selector: "scheduleTone:", userInfo: nil, repeats: false)
            NSRunLoop.mainRunLoop().addTimer(timer, forMode: NSRunLoopCommonModes)
        }
        
        playTone(lastTime)
        
        //		schedule next beat:
        
    }
    
    private func playTone(time:NSTimeInterval) {
        
//        print("play: \(time), \(curBeat), \(beatIndex)")
        saveEvent(.Audio, time: time)
        curBeat += 1
        
        //			find available player:
        //		print(playerPool[beatIndex].count)
        
        if playerPool.count > 0 {
            let player = playerPool.removeLast()
            player.playAtTime(time)
            print("success")
            return
        }
        
        //		otherwise just stop a player and use it:
        tonePlayers.last?.stop()
        tonePlayers.last?.playAtTime(time)
    }
    
    func stopPlaying(timer: NSTimer) {
        print("stopping")
        if donePlaying != nil {
            donePlaying()
        }
    }
    
}

extension ExpEngine : AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        playerPool.append(player)
        player.prepareToPlay()
    }
}

extension Int
{
	static func random(range: Range<Int> ) -> Int
	{
		var offset = 0
		
		if range.startIndex < 0   // allow negative ranges
		{
			offset = abs(range.startIndex)
		}
		
		let mini = UInt32(range.startIndex + offset)
		let maxi = UInt32(range.endIndex   + offset)
		
		return Int(mini + arc4random_uniform(maxi - mini)) - offset
	}
}