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
		case Slow
		case Normal
		case Fast
	}
	
	struct Task: CustomStringConvertible {
		var length: Int
		var repeats: Int
		var type: TaskType
		var description: String { return "\(type): \(repeats)x \(length)" }
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
	}
	
// storage:
	var taskHistory: [Task] = [Task]()
	var session: [Task] = [Task]()
	var sessionHistory = [[Task]]()
	
//	recording stuff
	var currentRecord: expRecord!

	var length: Int = 0
	var repeats: Int = 0
	
	var isRecording = false
	
	private var curRecording = [(type: Tap, dur: Double)]()
	private var curRecordingsAll = [[(type: Tap, dur: Double)]]()
	private var startTime: NSTimeInterval = 0
	private var curPracticeCount:Int = 0
	
//	override init() {
//		super.init()
//		session.append(Task(length: 10, repeats: 1, type: .Normal))
//		session[0] = Task(length: 20, repeats: 2, type: .Normal)
//	}
	
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
	}
	
	func tapUp() {
		saveEvent(.Up, time: NSDate().timeIntervalSince1970)
	}
	
	func tapDown() {
		saveEvent(.Down, time: NSDate().timeIntervalSince1970)
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
	
	private func saveToFile(seqs:[[(type: Tap, dur: Double)]], outlier:Bool) {
//		NSLog("salva me")
		//		make file name
//		let formatter = NSDateFormatter()
//		formatter.dateFormat = "yy.MM.dd-hh.mm.ss"
		var filename = currentRecord.fileName
		if outlier { filename = "r" + filename }
		
		let paths:NSArray = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
		let basePath: AnyObject! = (paths.count > 0) ? paths.objectAtIndex(0) : nil
		
		let baseName = String(basePath) + "/" + filename
		print("saving to \(baseName)")
		
		let fullpath1 = baseName + ".txt"
		let fullpath2 = baseName + ".csv"
		
		var lines = ""
		for seq in seqs {
			for e in seq {
				lines += "\(e.type), \(e.dur)\n"
			}
			lines += "\n"
		}
		
		do {
			try lines.writeToFile(fullpath1, atomically: false, encoding: NSUTF8StringEncoding)
		} catch {
			NSLog("bad:"+filename)
		}
		
//		write interval file
		lines = "\(curPracticeCount), "
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
//		let outlier = isOutlierFilter()
//		save current record to disk
		if save {
			saveToFile(curRecordingsAll, outlier:false)
		}
		
		curRecordingsAll.removeAll(keepCapacity: true)
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