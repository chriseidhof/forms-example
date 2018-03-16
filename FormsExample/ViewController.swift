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
    var personalHotspot = false
    var personalHotspotPassword: String = "hello"
    
    enum ShowPreview {
        case always
        case never
        case sometimes
        
        static var all: [ShowPreview] = [.always, .never, .sometimes]
        
        var text: String {
            switch self {
            case .always: return "Always"
            case .never: return "Never"
            case .sometimes: return "Sometimes"
            }
        }
    }
    
    var valid: Bool {
        return !name.isEmpty && !password.isEmpty
    }
    
    var validName: Bool { return !name.isEmpty }
    var validPassword: Bool { return !password.isEmpty }
    
    var showPreviews: ShowPreview = .always
    
    enum Message {
        case submit
    }
}

func tableForm() -> [FormElement<State,State.Message, Section>] {
    return [.section(headerTitle: "test", cells: [
        .cell({ _ in "Name" }, .textField(text: \State.name, placeHolder: "Your Name")),
        .cell({ _ in "Test"}, detailText: { _ in "Detail" }),
        .cell({ _ in "Password" }, .textField(text: \State.password, placeHolder: "Your Password", isSecure: { _ in true }), backgroundColor: { $0.validPassword ? .white : .red }),
        .cell({ $0.other ? "I want spam" : "No spam" }, FormElement<Bool, State.Message, UIView>.uiSwitch().bindTo(\State.other), hidden: { $0.validName }),
        .cell({ _ in "Personal Hotspot" }, detailText: { $0.personalHotspot ? "On" : "Off" }, accessory: { _ in .disclosureIndicator }, nested: personalHotspotForm),
        .cell({ _ in "" }, .button(title: { _ in "Submit"}, isEnabled: { (s: State) in s.valid }, onTap: .left(State.Message.submit)))
    ]),
    .section(headerTitle: "notifications", cells: [
        .cell({_ in "Show Previews" }, detailText: { $0.showPreviews.text }, accessory: { _ in .disclosureIndicator}, nested: nested)
    ]),
    ]
}

func nestedTextfield<Output>(title: String) -> FormElement<String, Output, FormCell> {
    let nested = FormElement.tableViewController(style: .grouped, form: .form(title: title, sections: [
        .section(cells: [
            FormElement<String, Output, FormCell>.cell({ _ in ""}, simpleTextField(placeHolder: title))
        ])
    ]))
    return FormElement.cell({ _ in title }, detailText: { $0 }, accessory: { _ in .disclosureIndicator }, nested: nested
    )
}

let personalHotspotForm: FormElement<State, State.Message, UITableViewController> = FormElement.tableViewController(style: .grouped, form: .form(title: "Test", sections: [
    .section(headerTitle: "", cells: [
        .cell({_ in "Personal Hotspot" }, FormElement<Bool, State.Message, UIView>.uiSwitch().bindTo(\State.personalHotspot)),
    ]),
    .section(headerTitle: "", footerTitle: "Other users will join the shared Wi-Fi network using the provided password.\n\nThis is a test.", cells: [
        nestedTextfield(title: "Wi-Fi Password").bindTo(\State.personalHotspotPassword)
    ])
    ]))

let nested: FormElement<State, State.Message, UITableViewController> = FormElement<State,State.Message, UITableViewController>.tableViewController(style: .grouped, form: FormElement.form(title: "Test", sections: [
    choice(title: "Show Previews", elements: State.ShowPreview.all.map {
        ($0, $0.text)
    }).bindTo(\State.showPreviews)
    ]))



class ViewController: UIViewController {
    var refs: [Any] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        buildTableView()
    }
    
    func buildTableView() {
        let table = FormElement.tableView(style: .grouped, sections: tableForm())
        let (s, refs) = driver(initial: State(), view: table, pushViewController: { [unowned self] in
            self.navigationController?.pushViewController($0, animated: true)
        }, onEvent: { (state, msg) in
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

