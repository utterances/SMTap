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
		var description: String { return "\(type.rawValue): \(repeats)x \(length)" }
		
		init(length: Int, repeats: Int, type: TaskType) {
			self.length = length
			self.repeats = repeats
			self.type = type
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
			
			repeats = Int(fields[1])!
			length = Int(fields[2])!
		}
	}
	
	struct Session: CustomStringConvertible {
		var tasks: [Task]
		var date: NSDate
		
		var description: String {
			var result = ""
			for t in tasks {
				if result.characters.count > 0 { result += " " }
				result += "\(t.type.rawValue.characters.first!)\(t.repeats)x\(t.length)"
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
	
	enum Tap: String {
		case Up
		case Down
        case Pos
	}
	
// storage:
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
	
	private var curRecording = [(type: Tap, dur: Double)]()
	private var curRecordingsAll = [[(type: Tap, dur: Double)]]()
    private var curPos = [CGPoint]()
    private var curPosAll = [[CGPoint]]()
	private var startTime: NSTimeInterval = 0
	
	override init() {
		super.init()
//        load seed file:
        
        let paths:NSArray = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
        
        let seedfilepath = basePath.stringByAppendingPathComponent("seeds.csv")
        
        var text: String
        do {
            text = try String(contentsOfFile: seedfilepath)
        } catch _ {
            print(basePath)
            let newSeq:[Double] = [500,500,500,2000,500,500,500]
            seedSeq[rhythmType.tempo.index].append(newSeq)
            return
        }
        
        //		first split by new line:
        var lines = text.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
        
        var splitlines = lines.map{ $0.componentsSeparatedByString(",") }
            .filter{ $0.count > 1 }
        seedSeq[rhythmType.tempo.index] = splitlines.map{ $0.map { Double($0)! } }
        
        seedSeq[rhythmType.tempo.index] = seedSeq[rhythmType.tempo.index].filter{ $0.count>0 }
        
        //		load rhythm seed
        let seedfilepath2 = basePath.stringByAppendingPathComponent("seeds/seeds_meter.csv")
        
        do {
            text = try String(contentsOfFile: seedfilepath2)
        } catch _ {
            let newSeq:[Double] = [640,640,320,640,320,320,640,320,320,640,640]
            seedSeq[rhythmType.meter.index].append(newSeq)
            seedSeqDownBeats.append([])
            return
        }
        
        //		first split by new line:
        lines = text.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
        
        splitlines = lines.map{ $0.componentsSeparatedByString(",") }
            .filter{ $0.count > 0 && Int($0.first!) != nil }
        
        seedSeq[rhythmType.meter.index] = []
        
        for i in 0..<Int(splitlines.count/2)*2 {
            if i % 2 == 0 {	// interval
                seedSeq[rhythmType.meter.index].append(splitlines[i].map{ Double($0)! })
            } else {
                seedSeqDownBeats.append(splitlines[i].map{ Int($0)! })
            }
        }
        
        
        //		load other files
        let documentsUrl =  NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as NSURL
        // now lets get the directory contents (including folders)
        let directoryUrls: [NSURL]
        do {
            directoryUrls = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(documentsUrl, includingPropertiesForKeys: nil, options: .SkipsSubdirectoryDescendants)
        } catch _ { return }
        
        let csvFiles = directoryUrls.filter{ $0.pathExtension == "csv" && $0.lastPathComponent!.characters.first != "r" }
        for csvf in csvFiles {
            let newRec = expRecord(withFileName: csvf)
            expRecords[newRec.ID] = newRec
        }
        
        //		maxChainLengths[.audio] = [[Int]]()
        //		maxChainLengths[.visual] = [[Int]]()
        
        //		init chainlength array
        //		for i in 0...1 {
        ////			for j in
        //			maxChainLengths[.audio]!.append([Int](count: seedSeq[i].count, repeatedValue: 0))
        //			maxChainLengths[.visual]!.append([Int](count: seedSeq[i].count, repeatedValue: 0))
        //		}
        
        //		also init openends too
        for (k,v) in expRecords {
            maxID = max(maxID, v.ID)
            
            guard v.chainLength < MaxChainLength else {
                print("ignore full chain length: \(v.chainLength)")
                continue }
            openEndIDs.append(k)
            
            //			guard v.sourceID < 1000 else { continue }
            //			let old = maxChainLengths[v.condition]![v.rhythm.index][v.sourceID]
            //			maxChainLengths[v.condition]![v.rhythm.index][v.sourceID] = max(old, v.chainLength)
        }
        
	}
	
	func seqToInterval(seq:[(type: Tap, dur: Double)]) -> [Double] {
//		convert up down data into interval format, use ms and lower precision
		var result = [Double]()
		
		var prevDur = seq[0].dur
		for i in 1..<seq.count {
			guard seq[i].type == .Down else {
				continue
			}
			
			var interval = (seq[i].dur - prevDur)*1000
			interval = round(100 * interval) / 100
			result.append(interval)
			prevDur = seq[i].dur
		}
		
		return result
	}

	func seqToString(seq:[(type: Tap, dur: Double)]) -> [String] {
		var result = [String]()
		
		for s in seq {
			if s.type == .Down {
				
				let interval =  round(s.dur*1000*100)/100
				let name = s.type.rawValue
				result.append("\(name[name.startIndex]):\(interval)")
			}
		}
		return result
	}
	
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
		
		let firstTime = curRecording[0].dur
		for i in 0..<curRecording.count {
			var e = curRecording[i]
			e.dur -= firstTime
			curRecording[i] = e
		}
		
//		save to record stash, save to file later
		curRecordingsAll.append(curRecording)
		curRecording.removeAll()
        curPosAll.append(curPos)
        curPos.removeAll()
	}
	
	func tapUp() {
		saveEvent(.Up, time: NSDate().timeIntervalSince1970)
	}
	
	func tapDown() {
		saveEvent(.Down, time: NSDate().timeIntervalSince1970)
	}
	
    func tapPos(pos: CGPoint) {
        saveEvent(.Pos, time: NSDate().timeIntervalSince1970)
        curPos.append(pos)
    }
    
	private func saveEvent(type: Tap, time: NSTimeInterval) {
		guard isRecording else {
			return	// sanity check here, shouldn't really happen
		}
		
		let dur = time - startTime
		curRecording.append((type, dur))
		
//		do filtering right now:
		
//		FIXME!
		if type == .Up && curRecording.count > 3 {
			let gap = curRecording[curRecording.count-2].dur - curRecording[curRecording.count-4].dur
			if gap < 0.05 {
				print("too fast \(gap)")
				curRecording.removeLast()
				curRecording.removeLast()
			}
		}
	}
	
    private func saveToFile(seqs:[[(type: Tap, dur: Double)]], posSeqs:[[CGPoint]], outlier:Bool) {
//		NSLog("salva me")
		//		make file name
		let formatter = NSDateFormatter()
		formatter.dateFormat = "yy.MM.dd-hh.mm.ss"
		var filename = currentRecord.fileName + " " + formatter.stringFromDate(NSDate())
		filename.appendContentsOf(" "+"\(curTask.type.rawValue.characters.first!)\(curTask.repeats)x \(curTask.length)")
		
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
	
	func addTask(length: Int, repeats: Int, type: TaskType) {
		let task = Task(length: length, repeats: repeats, type: type)
		session.append(task)
		addToHistory(task)
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