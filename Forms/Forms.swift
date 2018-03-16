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

struct RenderingContext<Input, Output> {
    let change: (@escaping (inout Input) -> ()) -> ()
    let output: (Output) -> ()
    let pushViewController: (UIViewController) -> ()
}
public struct FormElement<Input, Output, View> {
    public typealias Change = Either<Output, (inout Input) -> ()>
    let render: (_ context: RenderingContext<Input, Output>) -> RenderedFormElement<Input, View>
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

extension FormElement where View == UIView, Input == Bool {
    public static func uiSwitch() -> FormElement {
        return FormElement { out in
            let result = UISwitch()
            let ta = TargetAction { [unowned result] in out.change { s in
                s = result.isOn
                } }
            result.addTarget(ta, for: .valueChanged)
            return RenderedFormElement(view: result, strongReferences: [ta]) { input in
                result.isOn = input
            }
        }
    }
}
extension FormElement where View == UIView {
    public static func button(title: @escaping (Input) -> String, isEnabled: @escaping (Input) -> Bool, onTap: Change) -> FormElement {
        return FormElement { out in
            let result = UIButton()
            let ta = TargetAction { switch onTap {
            case .left(let x): out.output(x)
            case .right(let x): out.change(x)
                } }
            result.addTarget(ta, for: .touchUpInside)
            return RenderedFormElement(view: result, strongReferences: [ta]) { input in
                result.isEnabled = isEnabled(input)
                result.setTitle(title(input), for: .normal)
            }
        }
    }
    
    public static func textField(text: WritableKeyPath<Input, String>, placeHolder: String? = nil, isSecure: @escaping (Input) -> Bool = { _ in false}, backgroundColor: @escaping (Input) -> UIColor = { _ in .clear }) -> FormElement {
        return FormElement { out in
            let result = UITextField()
            result.placeholder = placeHolder
            let ta = TargetAction { [unowned result] in out.change { state in
                state[keyPath: text] = result.text ?? ""
            } }
            result.addTarget(ta, for: .editingChanged)
            return RenderedFormElement(view: result, strongReferences: [ta]) { input in
                result.text = input[keyPath: text]
                result.isSecureTextEntry = isSecure(input)
                result.backgroundColor = backgroundColor(input)
            }
        }
    }
}

public func simpleTextField<Output>(placeHolder: String? = nil) -> FormElement<String,Output,UIView> {
    return FormElement { out in
        let result = UITextField()
        result.placeholder = placeHolder
        let ta = TargetAction { [unowned result] in out.change { state in
            state = result.text ?? ""
            } }
        result.addTarget(ta, for: .editingChanged)
        return RenderedFormElement(view: result, strongReferences: [ta]) { input in
            result.text = input
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
    
    public var nested: UIViewController? = nil
    
    public var onHide: ((Bool) -> ())? = nil
    public var didSelect: (() -> ())? = nil
    
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
    public static func cell(style: UITableViewCellStyle = .value1, _ text: @escaping (Input) -> String, detailText: @escaping (Input) -> String = { _ in "" }, _ element: FormElement<Input, Output, UIView>? = nil, backgroundColor: @escaping (Input) -> UIColor = { _ in .white }, hidden: @escaping (Input) -> Bool = { _ in false }, accessory: @escaping (Input) -> UITableViewCellAccessoryType = { _ in .none }, nested: FormElement<Input, Output, UITableViewController>? = nil, didSelect: ((inout Input) -> ())? = nil) -> FormElement {
        return FormElement { out in
            let cell = FormCell(style: style)
            let renderedElement = element?.render(out)
            cell.formElement = renderedElement?.view
            let nestedRendered = nested?.render(out)
            cell.nested = nestedRendered?.view
            let strongReferences = [renderedElement?.strongReferences, nestedRendered?.strongReferences].flatMap { $0 }
            if let d = didSelect {
                cell.didSelect = { out.change(d) }
            }
            return RenderedFormElement(view: cell, strongReferences: strongReferences, updateForChangedInput: { input in
                cell.textLabel?.text = text(input)
                cell.backgroundColor = backgroundColor(input)
                cell.detailTextLabel?.text = detailText(input)
                cell.accessoryType = accessory(input)
                cell.hide = hidden(input)
                renderedElement?.updateForChangedInput(input)
                nestedRendered?.updateForChangedInput(input)
            })
        }
    }
}

final class StaticTableViewConfig: NSObject, UITableViewDataSource, UITableViewDelegate {
    private var observers: [Any] = []
    var sections: [Section] {
        didSet {
            addObservers()
        }
    }
    let push: (UIViewController) -> ()
    
    let tableView: UITableView
    init(tableView: UITableView, sections: [Section], push: @escaping (UIViewController) -> ()) {
        self.tableView = tableView
        self.tableView.estimatedRowHeight = 55
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.sections = sections
        self.push = push
        super.init()
        addObservers()
    }
    
    func addObservers() {
        for (i, section) in sections.enumerated() {
            for (j, cell) in section.cells.enumerated() {
                cell.onHide = { newValue in
                    print("hide row \(i,j)")
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = sections[indexPath.section].cells[indexPath.row]
        if let s = cell.didSelect {
            s()
        }
        if let n = cell.nested {
            push(n)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }
    
    
}

public struct Section {
    var headerTitle: String?
    var footerTitle: String?
    var cells: [FormCell]
}

extension FormElement where View == Section {
    public static func section(headerTitle: String? = nil, footerTitle: String? = nil, cells: [FormElement<Input,Output,FormCell>]) -> FormElement {
        return FormElement { out in
            let rendered = cells.map { $0.render(out) }
            return RenderedFormElement(view: Section(headerTitle: headerTitle, footerTitle: footerTitle, cells: rendered.map { $0.view }), strongReferences: rendered.flatMap { $0.strongReferences }, updateForChangedInput: { input in
                for r in rendered {
                    r.updateForChangedInput(input)
                }
            })
        }
    }
}

public struct Form {
    public var title: String
    public var sections: [Section]
}

final class FormViewController: UITableViewController {
    var form: Form
    var strongReferences: [Any] = []
    var manager: StaticTableViewConfig!
    
    init(_ form: Form, style: UITableViewStyle, push: @escaping (UIViewController) -> ()) {
        self.form = form
        super.init(style: style)
        manager = StaticTableViewConfig(tableView: tableView, sections: form.sections, push: push)
        tableView.delegate = manager
        tableView.dataSource = manager
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension FormElement where View == Form {
    // todo almost the same as Section
    public static func form(title: String, sections: [FormElement<Input,Output,Section>]) -> FormElement {
        return FormElement { out in
            let rendered = sections.map { $0.render(out) }
            return RenderedFormElement(view: Form(title: title, sections: rendered.map { $0.view }), strongReferences: rendered.flatMap { $0.strongReferences }, updateForChangedInput: { input in
                for r in rendered {
                    r.updateForChangedInput(input)
                }
            })

        }
    }
}

extension FormElement where View == UITableView {
    static public func tableView(style: UITableViewStyle, sections: [FormElement<Input, Output, Section>]) -> FormElement {
        // todo almost the same as section and form
        return FormElement { out in
            let tableView = UITableView(frame: .zero, style: style)
            let rendered = sections.map { $0.render(out) }
            let manager = StaticTableViewConfig(tableView: tableView, sections: rendered.map { $0.view }, push: out.pushViewController)
            tableView.dataSource = manager
            tableView.delegate = manager
            return RenderedFormElement(view: tableView, strongReferences: rendered.flatMap { $0.strongReferences } + [manager], updateForChangedInput: { input in
                for r in rendered {
                    r.updateForChangedInput(input)
                }
            })
            
        }
    }
}

extension FormElement where View == UITableViewController {
    static public func tableViewController(style: UITableViewStyle, form: FormElement<Input,Output,Form>) -> FormElement {
        return FormElement { out in
            let rendered = form.render(out)
            let vc = FormViewController(rendered.view, style: .grouped, push: out.pushViewController)
            vc.navigationItem.title = rendered.view.title
            return RenderedFormElement(view: vc, strongReferences: rendered.strongReferences, updateForChangedInput: { input in
                rendered.updateForChangedInput(input)
            })
        }
    }
}

extension RenderingContext {
    func project<Child>(_ keyPath: WritableKeyPath<Input,Child>) -> RenderingContext<Child, Output> {
        return RenderingContext<Child, Output>(change: { f in
            self.change { value in
                f(&value[keyPath: keyPath])
            }
        }, output: output, pushViewController: pushViewController)

    }
}

extension FormElement {
    public func bindTo<NewInput>(_ keyPath: WritableKeyPath<NewInput, Input>) -> FormElement<NewInput, Output, View> {
        return FormElement<NewInput, Output, View> { out in
            let result = self.render(out.project(keyPath))
            return RenderedFormElement(view: result.view, strongReferences: result.strongReferences, updateForChangedInput: { inp in
                result.updateForChangedInput(inp[keyPath: keyPath])
            })
        }
    }
}

public func choice<A: Equatable, Message>(title: String, elements: [(A, String)]) -> FormElement<A, Message, Section> {
    return .section(headerTitle: title, cells: elements.map { el in
        FormElement.cell({ _ in el.1 }, accessory: { $0 == el.0 ? .checkmark : .none}, didSelect: {
            $0 = el.0
        })
    })
}


public func driver<Input, Output, View>(initial: Input, view: FormElement<Input,Output,View>, pushViewController: @escaping (UIViewController) -> (), onEvent: @escaping (inout Input, Output) -> ()) -> (result: View, strongReferences: [Any]) {
    var updateForChangedState: () -> () = {}
    var state = initial {
        didSet {
            updateForChangedState()
            print(state)
        }
    }
    let context = RenderingContext(change: { f in
        f(&state)
    }, output: { o in
        onEvent(&state, o)
    }, pushViewController: pushViewController)
    let element = view.render(context)
    updateForChangedState = { element.updateForChangedInput(state) }
    updateForChangedState()
    return (element.view, element.strongReferences)
}
