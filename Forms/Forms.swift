//
//  Forms.swift
//  Forms
//
//  Created by Chris Eidhof on 01.03.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import Foundation

public final class TargetAction {
    let callback: () -> ()
    init(_ callback: @escaping () -> ()) {
        self.callback = callback
    }
    
    @objc func action(sender: Any) {
        self.callback()
    }
}

public struct RenderedFormElement<Input, View> {
    let view: View
    let strongReferences: [Any]
    let updateForChangedInput: (Input) -> ()
}

public enum Either<A,B> {
    case left(A)
    case right(B)
}

public struct FormElement<Input, Output, View> {
    public typealias Change = Either<Output, (inout Input) -> ()>
    let render: (_ callback: @escaping (Change) -> ()) -> RenderedFormElement<Input, View>
}

extension FormElement where View == UIView {
    public static func label(text: @escaping (Input) -> String) -> FormElement {
        return FormElement { _ in
            let result = UILabel()
            return RenderedFormElement(view: result, strongReferences: []) {
                result.text = text($0)
            }
        }
    }
    
    public static func empty() -> FormElement {
        return FormElement { _ in
            let result = UIView()
            return RenderedFormElement(view: result, strongReferences: []) { _ in () }
        }
    }
}

extension UIControl {
    public func addTarget(_ ta: TargetAction, for events: UIControlEvents) {
        self.addTarget(ta, action: #selector(TargetAction.action(sender:)), for: events)
    }
}

extension FormElement where View == UIView {
    public static func button(title: @escaping (Input) -> String, isEnabled: @escaping (Input) -> Bool, onTap: Change) -> FormElement {
        return FormElement { out in
            let result = UIButton()
            let ta = TargetAction { out(onTap) }
            result.addTarget(ta, for: .touchUpInside)
            return RenderedFormElement(view: result, strongReferences: [ta]) { input in
                result.isEnabled = isEnabled(input)
                result.setTitle(title(input), for: .normal)
            }
        }
    }
    
    public static func `switch`(isOn: WritableKeyPath<Input, Bool>) -> FormElement {
        return FormElement { out in
            let result = UISwitch()
            let ta = TargetAction { [unowned result] in out(Change.right { s in
                s[keyPath: isOn] = result.isOn
            }) }
            result.addTarget(ta, for: .valueChanged)
            return RenderedFormElement(view: result, strongReferences: [ta]) { input in
                result.isOn = input[keyPath: isOn]
            }
        }
    }
    
    public static func textField(text: WritableKeyPath<Input, String>, placeHolder: String? = nil, isSecure: @escaping (Input) -> Bool = { _ in false}, backgroundColor: @escaping (Input) -> UIColor = { _ in .clear }) -> FormElement {
        return FormElement { out in
            let result = UITextField()
            result.placeholder = placeHolder
            let ta = TargetAction { [unowned result] in out(Change.right { state in
                state[keyPath: text] = result.text ?? ""
            }) }
            result.addTarget(ta, for: .editingChanged)
            return RenderedFormElement(view: result, strongReferences: [ta]) { input in
                result.text = input[keyPath: text]
                result.isSecureTextEntry = isSecure(input)
                result.backgroundColor = backgroundColor(input)
            }
        }
    }
}

extension UIView {
    var frameRight: CGFloat? {
        get {
            guard let s = superview else { return nil }
            return s.bounds.width - frame.maxX
        }
        set {
            guard let s = superview else { return }
            frame.origin.x = s.bounds.width - frame.width - (newValue ?? 0)
        }
    }
    
    func centerVertically() {
        guard let s = superview else { return }
        frame.origin.y = (s.bounds.height - frame.height) / 2
    }
}

final public class FormCell: UITableViewCell {
    public var formElement: UIView? {
        didSet {
            if let o = oldValue { o.removeFromSuperview() }
            if let n = formElement {
                n.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(n)
                contentView.addConstraints([
                    n.centerYAnchor.constraint(equalTo: contentView.layoutMarginsGuide.centerYAnchor),
                    n.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
                ])
            }
        }
    }
    
    public var onHide: ((Bool) -> ())? = nil
    
    // override because I don't want to abuse isHidden
    public var hide: Bool = false {
        didSet {
            guard hide != oldValue else { return }
            onHide?(hide)
        }
    }
    
    init(style: UITableViewCellStyle) {
        super.init(style: style, reuseIdentifier: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FormElement where View == FormCell {
    public static func cell(style: UITableViewCellStyle = .value1, _ text: @escaping (Input) -> String, detailText: @escaping (Input) -> String = { _ in "" }, _ element: FormElement<Input, Output, UIView> = .empty(), backgroundColor: @escaping (Input) -> UIColor = { _ in .white }, hidden: @escaping (Input) -> Bool = { _ in false }) -> FormElement {
        return FormElement { out in
            let cell = FormCell(style: style)
            let renderedElement = element.render(out)
            renderedElement.view.frame.size = CGSize(width: 200, height: 30) // todo
            cell.formElement = renderedElement.view
            return RenderedFormElement(view: cell, strongReferences: [], updateForChangedInput: { input in
                cell.textLabel?.text = text(input)
                cell.backgroundColor = backgroundColor(input)
                cell.detailTextLabel?.text = detailText(input)
                renderedElement.updateForChangedInput(input)
                cell.hide = hidden(input)
            })
        }
    }
}

final class StaticTableViewConfig: NSObject, UITableViewDataSource {
    private var observers: [Any] = []
    var cells: [FormCell] {
        didSet {
            addObservers()
        }
    }
    let tableView: UITableView
    init(tableView: UITableView, cells: [FormCell]) {
        self.tableView = tableView
        self.tableView.estimatedRowHeight = 55
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.cells = cells
        super.init()
        addObservers()
    }
    
    func addObservers() {
        for (i, cell) in cells.enumerated() {
            cell.onHide = {
                print("hide at \(i, $0)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }
}

public func tableView<Input, Output>(initial: Input, cells: [FormElement<Input,Output,FormCell>], onEvent: @escaping (inout Input, Output) -> ()) -> (tableView: UITableView, strongReferences: [Any]) {
    var updateForChangedState: () -> () = {}
    var state = initial {
        didSet {
            updateForChangedState()
            print(state)
        }
    }
    let elements = cells.map { $0.render { out in
        switch out {
        case .left(let o):
            onEvent(&state, o)
        case .right(let f):
            f(&state)
        }
    } }
    var refs = elements.map { $0.strongReferences }
    updateForChangedState = { elements.forEach { $0.updateForChangedInput(state) } }
    updateForChangedState()
    let result = UITableView(frame: .zero, style: .grouped)
    let manager = StaticTableViewConfig(tableView: result, cells: elements.map { el in
        return el.view
    })
    result.dataSource = manager
    refs.append([manager])
    return (result, refs)
}
