//
//  ViewController.swift
//  SMTap
//
//  Created by Tim on 10/28/15.
//  Copyright © 2015 Q. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

	@IBOutlet weak var idField: UITextField!
	
	@IBOutlet weak var repeatSlider: UISlider!
	@IBOutlet weak var repeatLabel: UILabel!
	@IBOutlet weak var lengthField: UITextField!
	@IBOutlet weak var typeSegControl: UISegmentedControl!
	@IBOutlet weak var saveButton: UIButton!
	@IBOutlet weak var addTaskButton: UIButton!
	@IBOutlet weak var feedbackSwitch: UISwitch!
	
	@IBOutlet weak var loadSessionButton: UIButton!
	
	@IBOutlet weak var sessionTableview: UITableView!
	@IBOutlet weak var sessionHistoryTableView: UITableView!
	@IBOutlet weak var taskHistoryTableView: UITableView!
	
	var engine = ExpEngine()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		idField.delegate = self
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		sessionTableview.setEditing(true, animated: false)
		sessionHistoryTableView.reloadData()
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

//	MARK: - UI events

	@IBAction func sliderChanged(_ sender: UISlider) {
		let index = round(sender.value)
		sender.setValue(index, animated: true)
		repeatLabel.text = "\(Int(sender.value))"
		engine.repeats = Int(sender.value)
	}
	
    @IBAction func typeChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 3 {
            lengthField.text = "40"
        }
        
        if sender.selectedSegmentIndex == 3 {
            let selected = taskHistoryTableView.indexPathForSelectedRow
            if  selected == nil || (selected! as NSIndexPath).section != 1 {                taskHistoryTableView.selectRow(at: IndexPath(row: 0, section: 1), animated: true, scrollPosition: .top)
            }
        }
    }
    
	@IBAction func addTask(_ sender: UIButton) {
		sessionTableview.beginUpdates()
		
        if typeSegControl.selectedSegmentIndex != 3 {
            engine.addTask(Int(lengthField.text!)!, repeats: Int(repeatSlider.value), type: ExpEngine.TaskType.allValues[typeSegControl.selectedSegmentIndex])
        } else {
            let selected = taskHistoryTableView.indexPathForSelectedRow
            var seedID = 0
            if let selected = selected {
                seedID = (selected as NSIndexPath).section == 1 ? (selected as NSIndexPath).row : 0
            }
            
            engine.addTask(Int(lengthField.text!)!, repeats: Int(repeatSlider.value), type: .Sync, seedID: seedID)
        }
        
		sessionTableview.insertRows(at: [IndexPath(row: engine.session.count-1, section: 0)], with: .automatic)
		sessionTableview.endUpdates()
		taskHistoryTableView.reloadData()
	}
	
	@IBAction func saveTask(_ sender: UIButton) {
		if let i = sessionTableview.indexPathForSelectedRow {
			
			var task = ExpEngine.Task(length: Int(lengthField.text!)!, repeats: Int(repeatSlider.value), type: ExpEngine.TaskType.allValues[typeSegControl.selectedSegmentIndex])
			
			let indexpath = taskHistoryTableView.indexPathForSelectedRow
			if let index = indexpath {
				if (index as NSIndexPath).section == 1{
					task.seedID = (index as NSIndexPath).item
				}
			}
			
			engine.session[(i as NSIndexPath).item] = task
			engine.addToHistory(task)
			sessionTableview.reloadRows(at: [i], with: .right)
		}
		
		sender.isEnabled = false
        taskHistoryTableView.reloadData()
	}
	
	@IBAction func endEditLength(_ sender: UITextField) {
		if let i = Int(sender.text!) {
			sender.text = "\(i)"
		} else {
			sender.text = "16"
		}
	}
	
	@IBAction func startSession(_ sender: UIButton) {
		guard engine.session.count > 0 else {
			let alertVC = UIAlertController(title: "Session is Empty", message: "Can't start an empty sesison, add some tasks or load from history.", preferredStyle: .alert)
			let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
			alertVC.addAction(okAction)
			present(alertVC, animated: true, completion: nil)
			return
		}
		
		guard !(idField.text!.isEmpty) else {
			let alertVC = UIAlertController(title: "No User ID", message: "Please enter a user ID to start a session", preferredStyle: .alert)
			let okAction = UIAlertAction(title: "OK", style: .default) { _ in
				self.idField.becomeFirstResponder()
			}
			alertVC.addAction(okAction)
			present(alertVC, animated: true, completion: nil)
			return
		}
		
		engine.saveSession()
		engine.showFeedback = feedbackSwitch.isOn
		performSegue(withIdentifier: "showExpView", sender: self)
	}
	
	@IBAction func saveSession(_ sender: UIButton) {
		engine.saveSession()
		sessionHistoryTableView.reloadData()
	}
	
	@IBAction func clearTasks(_ sender: UIButton) {
		guard !engine.taskHistory.isEmpty else { return }
		clearTable(taskHistoryTableView, sender: sender)
			{ self.engine.taskHistory.removeAll() }
	}
	
	@IBAction func clearSession(_ sender: UIButton) {
		guard !engine.session.isEmpty else { return }
		clearTable(sessionTableview, sender: sender)
			{ self.engine.session.removeAll() }
	}

	@IBAction func clearSessionHistory(_ sender: UIButton) {
		guard !engine.sessionHistory.isEmpty else { return }
		clearTable(sessionHistoryTableView, sender: sender)
			{ self.engine.sessionHistory.removeAll() }
	}
	
	fileprivate func clearTable(_ tableView: UITableView, sender: UIView, clearBlock: @escaping ()->Void ) {
		let confirmVC = UIAlertController(title: "", message: "Clear all?", preferredStyle: .actionSheet)
		let clearAction = UIAlertAction(title: "Clear", style: .destructive) { _ in
			clearBlock()
			tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
		}
		
		let cancelAction = UIAlertAction(title:"Cancel", style: .cancel){_ in }
		
		confirmVC.addAction(clearAction)
		confirmVC.addAction(cancelAction)
		confirmVC.popoverPresentationController?.sourceView = sender
		confirmVC.popoverPresentationController?.sourceRect = CGRect(origin:CGPoint(x: sender.frame.width/2, y: sender.frame.height), size: CGSize.zero)
		confirmVC.popoverPresentationController?.permittedArrowDirections = .up
		present(confirmVC, animated: true, completion: nil)
	}
	
    @IBAction func loadSession(_ sender: UIButton) {
        if let i = sessionHistoryTableView.indexPathForSelectedRow {
            engine.session = engine.sessionHistory[(i as NSIndexPath).item].tasks
            sessionTableview.reloadSections(IndexSet(integer: 0), with: .left)
        }
    }
    
//	MARK: nav
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		// Get the new view controller using segue.destinationViewController.
		// Pass the selected object to the new view controller.
		if segue.destination is ExpViewController {
			engine.length = Int(lengthField.text!)!
			engine.startNewRecord(idField.text!)
			
			(segue.destination as! ExpViewController).engine = engine
		}
	}
	

	
}

extension ViewController: UITextFieldDelegate {
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		guard textField == lengthField else { return true }
		let numbers = "0123456789"
		for c in string.characters {
			if !numbers.characters.contains(c) { return false }
		}
		return true
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return false
	}

}

extension ViewController: UITableViewDelegate {
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let task: ExpEngine.Task
		switch tableView {
		case sessionTableview:
			if let i = taskHistoryTableView.indexPathForSelectedRow {
				taskHistoryTableView.deselectRow(at: i, animated: true)
			}
			saveButton.isEnabled = true
			task = engine.session[(indexPath as NSIndexPath).item]
		case taskHistoryTableView:
            guard (indexPath as NSIndexPath).section == 0 else { return }
            
			if let i = sessionTableview.indexPathForSelectedRow {
				sessionTableview.deselectRow(at: i, animated: true)
			}
			saveButton.isEnabled = false
			task = engine.taskHistory[(indexPath as NSIndexPath).item]
		case sessionHistoryTableView:
			loadSessionButton.isEnabled = true
			return
		default: return
		}
		
//		load task in "editor"
		
		repeatSlider.value = Float(task.repeats)
		repeatLabel.text = "\(task.repeats)"
		typeSegControl.selectedSegmentIndex = ExpEngine.TaskType.allValues.index(of: task.type)!
		

		lengthField.text = "\(task.length)"
		
		if task.type == .Sync {
			taskHistoryTableView.selectRow(at: IndexPath(row: task.seedID, section: 1), animated: true, scrollPosition: .top)
		}
	}
    
	@objc(tableView:commitEditingStyle:forRowAtIndexPath:) func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			// Delete the row from the data source
			switch tableView {
			case sessionTableview:
				engine.session.remove(at: (indexPath as NSIndexPath).item)
			case taskHistoryTableView:
				engine.taskHistory.remove(at: (indexPath as NSIndexPath).item)
			case sessionHistoryTableView:
				engine.sessionHistory.remove(at: (indexPath as NSIndexPath).item)
			default: return
			}
			tableView.deleteRows(at: [indexPath], with: .left)
		}
	}
}

extension ViewController: UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch tableView {
		case sessionTableview:			return engine.session.count
		case sessionHistoryTableView:	return engine.sessionHistory.count
		case taskHistoryTableView:
            switch section {
            case 0:
                return engine.taskHistory.count
            case 1:
                return engine.seeds.count
            default: return 0
            }
		default: return 0
	 	}
	}
	
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard tableView == taskHistoryTableView else { return nil }
        return section == 0 ? "Previous Tasks" : "Seeds (seeds.csv)"
    }
    
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "taskCell", for: indexPath)
		switch tableView {
		case sessionTableview:
			cell.textLabel?.text = engine.session[(indexPath as NSIndexPath).item].description
		case sessionHistoryTableView:
			cell.textLabel?.text = engine.sessionHistory[(indexPath as NSIndexPath).item].description
			cell.detailTextLabel?.text = engine.sessionHistory[(indexPath as NSIndexPath).item].dateString
		case taskHistoryTableView:
            if (indexPath as NSIndexPath).section == 0 {
                cell.textLabel?.text = engine.taskHistory[(indexPath as NSIndexPath).item].description
            } else {
                let strseed = engine.seeds[(indexPath as NSIndexPath).item].map{"\($0)"}
                
                cell.textLabel?.text = strseed.reduce(""){$0! + " "
                    + $1}
            }
		default: break
		}
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return tableView == sessionTableview
	}

	// Override to support rearranging the table view.
	func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to toIndexPath: IndexPath) {
		assert(tableView == sessionTableview)
		let f = engine.session[(fromIndexPath as NSIndexPath).item]
		let t = engine.session[(toIndexPath as NSIndexPath).item]
		engine.session[(toIndexPath as NSIndexPath).item] = f
		engine.session[(fromIndexPath as NSIndexPath).item] = t
	}
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableView == taskHistoryTableView ? 2 : 1
    }
}
