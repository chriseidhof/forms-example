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

func form<E: Element>() -> [E] where E.Input == State, E.Message == State.Message {
    return [
        .label { _ in "Name" },
        .textField(text: \.name, backgroundColor: { $0.validName ? .white : .red }),
        .label { _ in "Password" },
        .textField(text: \.password, isSecure: { _ in true }, backgroundColor: { $0.validPassword ? .white : .red }),
        .button(title: { _ in "Submit" }, enabled: { $0.valid }, onTap: State.Message.submit)
    ]
}

func tableForm() -> [Cell<State,State.Message>] {
    return [
    Cell({ _ in "Name" }, .textField(text: \.name, backgroundColor: { $0.validName ? .white : .red })),
    Cell({ _ in "Password" }, .textField(text: \.password, isSecure: { _ in true }, backgroundColor: { $0.validPassword ? .white : .red }), backgroundColor: { $0.validPassword ? .white : .red }),
    Cell({ _ in "Spam" }, .switch(isOn: \.other))
    ]
}

class ViewController: UIViewController {
    var refs: [Any] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        buildTableView()
    }
    
    func buildTableView() {
        let (s, refs) = tableView(initial: State(), cells: tableForm(), message: {
            print($0)
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
    
    func buildStackView() {
        let (s, refs) = stackView(initial: State(), renderers: form(), message: {
            print($0)
        })
        self.refs = refs
        
        s.axis = .vertical
        s.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(s)
        let si = view.safeAreaLayoutGuide
        view.addConstraints([
            s.topAnchor.constraint(equalTo: si.topAnchor),
            s.leftAnchor.constraint(equalTo: si.leftAnchor),
            s.rightAnchor.constraint(equalTo: si.rightAnchor)
            ])
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

