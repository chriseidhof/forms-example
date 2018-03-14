//
//  ViewController.swift
//  FormsExample
//
//  Created by Chris Eidhof on 01.03.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit
import Forms

struct State {
    var name: String = "Your Name"
    var password: String = "The Password"
    var other: Bool = false
    
    var valid: Bool {
        return !name.isEmpty && !password.isEmpty
    }
    
    var validName: Bool { return !name.isEmpty }
    var validPassword: Bool { return !password.isEmpty }
    
    enum Message {
        case submit
    }
}

func tableForm() -> [FormElement<State,State.Message, FormCell>] {
    return [
    .cell({ _ in "Name" }, .textField(text: \State.name, placeHolder: "Your Name")),
    .cell({ _ in "Test"}, detailText: { _ in "Detail" }),
    .cell({ _ in "Password" }, .textField(text: \.password, placeHolder: "Your Password", isSecure: { _ in true }), backgroundColor: { $0.validPassword ? .white : .red }),
    .cell({ _ in "Spam" }, .switch(isOn: \.other), hidden: { $0.validName }),
    .cell({ _ in "" }, .button(title: { _ in "Submit"}, isEnabled: { (s: State) in s.valid }, onTap: .left(State.Message.submit)))
    ]
}

class ViewController: UIViewController {
    var refs: [Any] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        buildTableView()
    }
    
    func buildTableView() {
        let (s, refs) = tableView(initial: State(), cells: tableForm(), onEvent: { (state, msg) in
            print(msg)
            print(state)
        })
        self.refs = refs
        
        s.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(s)
        let si = view.safeAreaLayoutGuide
        view.addConstraints([
            s.topAnchor.constraint(equalTo: si.topAnchor),
            s.leftAnchor.constraint(equalTo: si.leftAnchor),
            s.rightAnchor.constraint(equalTo: si.rightAnchor),
            s.bottomAnchor.constraint(equalTo: si.bottomAnchor)
            ])
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

