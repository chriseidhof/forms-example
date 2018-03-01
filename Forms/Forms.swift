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

public struct RenderedElement<I> {
    let view: UIView
    let strongReferences: [Any]
    let inputChanged: (I) -> ()
    init(view: UIView, inputChanged: @escaping (I) -> (), strongReferences: [Any] = []) {
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
    let render: (_ change: @escaping (Change<I, M>) -> ()) -> RenderedElement<I>
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
        return Renderer { change in
            let l = UILabel()
            return RenderedElement(view: l, inputChanged: {
                    l.text = text($0)
            })
        }
    }
    
    public static func _textField(text: WritableKeyPath<Input, String>, isSecure: @escaping (Input) -> Bool, backgroundColor: @escaping (Input) -> UIColor) -> Renderer<Input, Message> {
        return Renderer { change in
            let t = UITextField()
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
    
    public static func button(title: @escaping (Input) -> String, enabled: @escaping (Input) -> Bool, onTap: Message) -> Renderer<Input, Message> {
        return Renderer { change in
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
    let elements = renderers.map { (r: Renderer<State, Message>) -> RenderedElement<State> in
        r.render( { change in
            switch change {
            case let .message(m):
                message(m)
            case let .stateChange(f):
                f(&state)
            }
        })
    }
    let refs = elements.map { $0.strongReferences }
    updateForChangedState = { elements.forEach { $0.inputChanged(state) } }
    updateForChangedState()
    return (UIStackView(arrangedSubviews: elements.map { $0.view }), refs)
}
