//
//  Forms.swift
//  Forms
//
//  Created by Chris Eidhof on 01.03.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import Foundation

public protocol Element {
    associatedtype Input
    associatedtype Message
    static func label(text: @escaping (Input) -> String) -> Self
    static func button(title: @escaping (Input) -> String, enabled: @escaping (Input) -> Bool, onTap: Message) -> Self
    static func `switch`(isOn: WritableKeyPath<Input, Bool>) -> Self

    static func _textField(text: WritableKeyPath<Input, String>, isSecure: @escaping (Input) -> Bool, backgroundColor: @escaping (Input) -> UIColor) -> Self
}

extension Element {
    public static func textField(text: WritableKeyPath<Input, String>, isSecure: @escaping (Input) -> Bool = { _ in false }, backgroundColor: @escaping (Input) -> UIColor = { _ in .white }) -> Self {
        return ._textField(text: text, isSecure: isSecure, backgroundColor: backgroundColor)
    }
    
    public static func button(title: @escaping (Input) -> String, onTap: Message) -> Self {
        return .button(title: title, enabled: { _ in true }, onTap: onTap)
    }

}

public struct RenderedElement<I, V> {
    let view: V
    let strongReferences: [Any]
    let inputChanged: (I) -> ()
    init(view: V, inputChanged: @escaping (I) -> (), strongReferences: [Any] = []) {
        self.view = view
        self.inputChanged = inputChanged
        self.strongReferences = strongReferences
    }
}


enum Change<Input, Message> {
    case message(Message)
    case stateChange((inout Input) -> ())
}

public struct Renderer<I, M> {
    let render: (_ change: @escaping (Change<I, M>) -> (), _ align: NSTextAlignment) -> RenderedElement<I, UIView>
}

private final class TargetAction {
    let callback: () -> ()
    init(_ callback: @escaping () -> ()) {
        self.callback = callback
    }
    
    @objc func action(sender: Any) {
        self.callback()
    }
}

extension Renderer: Element {
    public typealias Input = I
    public typealias Message = M
    
    public static func label(text: @escaping (Input) -> String) -> Renderer<Input, Message> {
        return Renderer { change, alignment in
            let l = UILabel()
            l.textAlignment = alignment
            return RenderedElement(view: l, inputChanged: {
                    l.text = text($0)
            })
        }
    }
    
    public static func _textField(text: WritableKeyPath<Input, String>, isSecure: @escaping (Input) -> Bool, backgroundColor: @escaping (Input) -> UIColor) -> Renderer<Input, Message> {
        return Renderer { change, alignment in
            let t = UITextField()
            t.textAlignment = alignment
            let ta = TargetAction {
                change(.stateChange { (s: inout Input) in
                    s[keyPath: text] = t.text ?? ""
                })
            }
            t.addTarget(ta, action: #selector(TargetAction.action(sender:)), for: .editingChanged)
            return RenderedElement(view: t, inputChanged: { i in
                if t.text != i[keyPath: text] {
                    t.text = i[keyPath: text]
                }
                t.isSecureTextEntry = isSecure(i)
                t.backgroundColor = backgroundColor(i)
            }, strongReferences: [ta])
        }
    }
    
    public static func `switch`(isOn: WritableKeyPath<Input,  Bool>) -> Renderer<Input, Message> {
        return Renderer { change, alignment in
            let t = UISwitch()
            let ta = TargetAction {
                change(.stateChange { (s: inout Input) in
                    s[keyPath: isOn] = t.isOn
                    })
            }
            t.addTarget(ta, action: #selector(TargetAction.action(sender:)), for: .valueChanged)
            return RenderedElement(view: t, inputChanged: { i in
                if t.isOn != i[keyPath: isOn] {
                    t.isOn = i[keyPath: isOn]
                }
            }, strongReferences: [ta])
        }
    }
    
    public static func button(title: @escaping (Input) -> String, enabled: @escaping (Input) -> Bool, onTap: Message) -> Renderer<Input, Message> {
        return Renderer { change, alignment in
            let ta = TargetAction {
                change(.message(onTap))
            }

            let b = UIButton(type: .custom)
            b.addTarget(ta, action: #selector(TargetAction.action(sender:)), for: .touchUpInside)
            b.backgroundColor = .lightGray
            return RenderedElement(view: b, inputChanged: {
                b.setTitle(title($0), for: .normal)
                b.isEnabled = enabled($0)
            }, strongReferences: [ta])
        }
    }
}

public func stackView<State, Message>(initial: State, renderers: [Renderer<State, Message>], message: @escaping (Message) -> ()) -> (stackView: UIStackView, strongReferences: [Any]) {
    var updateForChangedState: () -> () = {}
    var state = initial {
        didSet {
            updateForChangedState()
        }
    }
    let elements = renderers.map { (r: Renderer<State, Message>) -> RenderedElement<State, UIView> in
        r.render( { change in
            switch change {
            case let .message(m):
                message(m)
            case let .stateChange(f):
                f(&state)
            }
        }, .left)
    }
    let refs = elements.map { $0.strongReferences }
    updateForChangedState = { elements.forEach { $0.inputChanged(state) } }
    updateForChangedState()
    return (UIStackView(arrangedSubviews: elements.map { $0.view }), refs)
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
            print(s.bounds.width, frame.width, (newValue ?? 0))
        }
    }
    
    func centerVertically() {
        guard let s = superview else { return }
        frame.origin.y = (s.bounds.height - frame.height) / 2
    }
}

final class FormCell: UITableViewCell {
    let formElement: UIView
    
    init(label: String, _ formElement: UIView) {
        self.formElement = formElement
        super.init(style: .value1, reuseIdentifier: nil)
        textLabel?.text = label
        contentView.addSubview(formElement)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        formElement.frameRight = 20
        formElement.centerVertically()
    }
}

final class StaticTableViewConfig: NSObject, UITableViewDataSource {
    var cells: [UITableViewCell]
    let tableView: UITableView
    init(tableView: UITableView, cells: [UITableViewCell]) {
        self.tableView = tableView
        self.cells = cells
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }
}

public struct Cell<State, Message> {
    let text: (State) -> String
    let backgroundColor: (State) -> UIColor
    let element: Renderer<State, Message>
    public init(_ text: @escaping (State) -> String, _ element: Renderer<State, Message>, backgroundColor: @escaping (State) -> UIColor = { _ in .white }) {
        self.text = text
        self.element = element
        self.backgroundColor = backgroundColor
    }
}

extension Cell {
    func render(_ change: @escaping (Change<State, Message>) -> ()) -> RenderedElement<State, UITableViewCell> {
        let re = element.render(change, .right)
        re.view.frame.size = CGSize(width: 200, height: 30) // todo
        let cell = FormCell(label: "one", re.view)
        return RenderedElement<State, UITableViewCell>(view: cell, inputChanged: { newInput in
            cell.textLabel?.text = self.text(newInput)
            cell.backgroundColor = self.backgroundColor(newInput)
            re.inputChanged(newInput)
        }, strongReferences: re.strongReferences)
    }
}

public func tableView<State, Message>(initial: State, cells: [Cell<State, Message>], message: @escaping (Message) -> ()) -> (tableView: UITableView, strongReferences: [Any]) {
    var updateForChangedState: () -> () = {}
    var state = initial {
        didSet {
            updateForChangedState()
            print(state)
        }
    }
    let elements = cells.map { (c: Cell<State, Message>) -> RenderedElement<State, UITableViewCell> in
        return c.render( { change in
            switch change {
            case let .message(m):
                message(m)
            case let .stateChange(f):
                f(&state)
            }
        })
    }
    var refs = elements.map { $0.strongReferences }
    updateForChangedState = { elements.forEach { $0.inputChanged(state) } }
    updateForChangedState()
    let result = UITableView(frame: .zero, style: .grouped)
    let manager = StaticTableViewConfig(tableView: result, cells: elements.map { el in
        return el.view
    })
    result.dataSource = manager
    refs.append([manager])
    return (result, refs)
}
