//  Copyright © 2017 Stefan van den Oord. All rights reserved.

import Quick
import Nimble
import ReSwift
import ReRxSwift
import UIKit
import RxSwift
import RxCocoa
import RxDataSources

let initialState = TestState(someString: "initial string", someFloat: 0.42, numbers: [],
                             someNonEquatable: NonEquatableStruct(str: "initial non equatable"))

protocol NonEquatable {
    var str: String { get }
}

struct NonEquatableStruct: NonEquatable {
    let str: String
}

class SomeView: UIView {
    var nonEquatableProp: NonEquatable?
}

extension Reactive where Base: SomeView {
    var nonEquatable: Binder<NonEquatable> {
        return Binder(self.base) { someView, nonEquatable in
            someView.nonEquatableProp = nonEquatable
        }
    }

    var optNonEquatable: Binder<NonEquatable?> {
        return Binder(self.base) { someView, nonEquatable in
            someView.nonEquatableProp = nonEquatable
        }
    }
}

struct ViewControllerProps {
    let str: String
    let optStr: String?
    let flt: Float
    let sections: [TestSectionModel]
    let optInt: Int?
    let nonEquatable: NonEquatable
    let optNonEquatable: NonEquatable?
    let arrayNonEquatable: [NonEquatable]
}

struct ViewControllerActions {
    let setNewString: (String) -> Void
}

struct DummyAction: Action {}

class ConnectionSpec: QuickSpec {
    override func spec() {
        describe("sub - unsub") {
            var testStore: Store<TestState>!
            var mapStateToPropsCalled: Bool? = nil
            var connection: Connection<TestState, SimpleProps, SimpleActions>!

            beforeEach {
                testStore = Store<TestState>(
                    reducer: {(_,state) in return state!},
                    state: initialState)
                connection = Connection(
                    store: testStore,
                    mapStateToProps: { _ in
                        mapStateToPropsCalled = true
                        return SimpleProps(str: "")
                    },
                    mapDispatchToActions: mapDispatchToActions
                )
                mapStateToPropsCalled = nil
            }

            it("subscribes to the store when connecting") {
                connection.connect()
                testStore.dispatch(DummyAction())
                expect(mapStateToPropsCalled).to(beTrue())
            }

            context("when it is subscribed") {
                beforeEach {
                    connection.connect()
                    mapStateToPropsCalled = nil
                }

                it("unsubscribes from the store when disconnecting") {
                    connection.disconnect()
                    testStore.dispatch(DummyAction())
                    expect(mapStateToPropsCalled).to(beNil())
                }
            }
        }

        context("given a connection") {
            var testStore : Store<TestState>! = nil
            var connection: Connection<TestState, ViewControllerProps, ViewControllerActions>!
            let mapStateToProps = { (state: TestState) in
                return ViewControllerProps(
                    str: state.someString,
                    optStr: state.someString,
                    flt: state.someFloat,
                    sections: state.sections,
                    optInt: state.maybeInt,
                    nonEquatable: state.someNonEquatable,
                    optNonEquatable: state.maybeNonEquatable,
                    arrayNonEquatable: state.arrayNonEquatable
                )
            }
            let mapDispatchToActions = { (dispatch: @escaping DispatchFunction) in
                return ViewControllerActions(
                    setNewString: { str in dispatch(TestAction(newString: str)) }
                )
            }

            beforeEach {
                testStore = Store<TestState>(
                    reducer: {(_,state) in return state!},
                    state: initialState)
                connection = Connection(
                    store:testStore,
                    mapStateToProps: mapStateToProps,
                    mapDispatchToActions: mapDispatchToActions
                )
            }

            it("uses store's initial state for initial props value") {
                expect(connection.props.value.str) == initialState.someString
            }

            it("can set and get props") {
                connection.props.accept(
                    ViewControllerProps(str: "some props",
                                        optStr: nil, flt: 0, sections: [], optInt: nil,
                                        nonEquatable: NonEquatableStruct(str: ""),
                                        optNonEquatable: nil, arrayNonEquatable: [])
                )
                expect(connection.props.value.str) == "some props"
            }

            it("sets new props when receiving new state from ReSwift") {
                let newState = TestState(someString: "new string", someFloat: 0, numbers: [],
                                         someNonEquatable: NonEquatableStruct(str: ""))
                connection.newState(state: newState)
                expect(connection.props.value.str) == newState.someString
            }

            it("maps actions using the store's dispatch function") {
                var dispatchedAction: Action? = nil
                testStore.dispatchFunction = { (action:Action) in dispatchedAction = action }

                connection.actions.setNewString("new string")
                expect(dispatchedAction as? TestAction) == TestAction(newString: "new string")
            }

            it("can subscribe to a props entry") {
                var next: String? = nil
                connection.subscribe(\ViewControllerProps.str) { nextStr in
                    next = nextStr
                }
                let newState = TestState(someString: "new string", someFloat: 0, numbers: [],
                                         someNonEquatable: NonEquatableStruct(str: ""))
                connection.newState(state: newState)
                expect(next) == "new string"
            }

            it("can subscribe to an optional props entry") {
                var next: Int? = nil
                connection.subscribe(\ViewControllerProps.optInt) { nextInt in
                    next = nextInt
                }
                let newState = TestState(someString: "", someFloat: 0, numbers: [], maybeInt: 42,
                                         someNonEquatable: NonEquatableStruct(str: ""))
                connection.newState(state: newState)
                expect(next) == 42
            }

            it("can subscribe to an optional non-equatable props entry") {
                var next: NonEquatable? = nil
                connection.subscribe(\ViewControllerProps.nonEquatable, isEqual: { $0.str == $1.str }) { nextNonEquatable in
                    next = nextNonEquatable
                }
                let newState = TestState(someString: "", someFloat: 0, numbers: [],
                                         someNonEquatable: NonEquatableStruct(str: "new string"))
                connection.newState(state: newState)
                expect(next?.str) == "new string"
            }

            it("can subscribe to an array-typed props entry") {
                var next: [TestSectionModel] = []
                connection.subscribe(\ViewControllerProps.sections) { nextSections in
                    next = nextSections
                }
                let newSection = TestSectionModel(header: "", items: [])
                let newState = TestState(someString: "", someFloat: 0, numbers: [], sections: [newSection],
                                         someNonEquatable: NonEquatableStruct(str: ""))
                connection.newState(state: newState)
                expect(next) == [newSection]
            }

            it("can subscribe to a non-equatable array-typed props entry") {
                var next: [NonEquatable] = []
                connection.subscribe(\ViewControllerProps.arrayNonEquatable, isEqual: { $0.str == $1.str }) { nextArray in
                    next = nextArray
                }
                let newArray = [NonEquatableStruct(str: "new string")]
                let newState = TestState(someString: "", someFloat: 0, numbers: [],
                                         someNonEquatable: NonEquatableStruct(str: ""), arrayNonEquatable: newArray)
                connection.newState(state: newState)
                expect(next[0].str) == newArray[0].str
            }

            describe("binding") {
                it("can bind an optional observer") {
                    let textField = UITextField()
                    connection.bind(\ViewControllerProps.str, to: textField.rx.text)
                    connection.newState(state: TestState(someString: "textField.text", someFloat: 0.0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(textField.text) == "textField.text"
                }

                it("can bind an optional non-equatable observer") {
                    let someView = SomeView(frame: .zero)
                    connection.bind(\ViewControllerProps.nonEquatable, to: someView.rx.optNonEquatable, isEqual: { $0.str == $1.str })
                    connection.newState(state: TestState(someString: "", someFloat: 0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "some.value")))
                    expect(someView.nonEquatableProp?.str) == "some.value"
                }

                it("can bind an optional observer using additional mapping") {
                    let textField = UITextField()
                    connection.bind(\ViewControllerProps.flt, to: textField.rx.text, mapping: { String($0) })
                    connection.newState(state: TestState(someString: "", someFloat: 42.42, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(textField.text) == "42.42"
                }

                it("can bind an optional non-equatable observer using additional mapping") {
                    let textField = UITextField()
                    connection.bind(\ViewControllerProps.nonEquatable, to: textField.rx.text, isEqual: { $0.str == $1.str }, mapping: { $0.str })
                    connection.newState(state: TestState(someString: "", someFloat: 0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "13.37")))
                    expect(textField.text) == "13.37"
                }

                it("it can bind to an optional prop") {
                    let textField = UITextField()
                    connection.bind(\ViewControllerProps.optInt, to: textField.rx.isHidden) { $0 == nil }
                    connection.newState(state: TestState(someString: "", someFloat: 0, numbers: [], maybeInt: nil,
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(textField.isHidden).to(beTrue())
                    connection.newState(state: TestState(someString: "", someFloat: 0, numbers: [], maybeInt: 42,
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(textField.isHidden).to(beFalse())
                }

                it("it can bind to an optional non-equatable prop") {
                    let textField = UITextField()
                    connection.bind(\ViewControllerProps.optNonEquatable, to: textField.rx.isHidden, isEqual: { $0?.str == $1?.str }) { $0 == nil }
                    connection.newState(state: TestState(someString: "", someFloat: 0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: ""),
                                                         maybeNonEquatable: nil))
                    expect(textField.isHidden).to(beTrue())
                    connection.newState(state: TestState(someString: "", someFloat: 0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: ""),
                                                         maybeNonEquatable:  NonEquatableStruct(str: "whatever")))
                    expect(textField.isHidden).to(beFalse())
                }

                it("can bind a non-optional observer") {
                    let progressView = UIProgressView()
                    connection.bind(\ViewControllerProps.flt, to: progressView.rx.progress)
                    connection.newState(state: TestState(someString: "", someFloat: 0.42, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(progressView.progress) ≈ 0.42
                }

                it("can bind a non-optional non-equatable observer") {
                    let someView = SomeView(frame: .zero)
                    connection.bind(\ViewControllerProps.nonEquatable, to: someView.rx.nonEquatable, isEqual: { $0.str == $1.str })
                    connection.newState(state: TestState(someString: "", someFloat: 0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "some.value")))
                    expect(someView.nonEquatableProp?.str) == "some.value"
                }

                it("can bind a non-optional observer using additional mapping") {
                    let progressView = UIProgressView()
                    connection.bind(\ViewControllerProps.str, to: progressView.rx.progress, mapping: { Float($0) ?? 0 })
                    connection.newState(state: TestState(someString: "0.42", someFloat: 0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(progressView.progress) ≈ 0.42
                }

                it("can bind a non-optional non-equatable observer using additional mapping") {
                    let progressView = UIProgressView()
                    connection.bind(\ViewControllerProps.nonEquatable, to: progressView.rx.progress, isEqual: { $0.str == $1.str }) { Float($0.str) ?? 0 }
                    connection.newState(state: TestState(someString: "", someFloat: 0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "0.42")))
                    expect(progressView.progress) ≈ 0.42
                }

                it("can bind colletion view items") {
                    let collectionView = UICollectionView(
                        frame: CGRect(),
                        collectionViewLayout: UICollectionViewFlowLayout())
                    let dataSource = RxCollectionViewSectionedReloadDataSource<TestSectionModel>(
                        configureCell: { _,_,_,_ in return UICollectionViewCell() },
                        configureSupplementaryView: { _,_,_,_ in return UICollectionReusableView() })
                    connection.bind(\ViewControllerProps.sections, to: collectionView.rx.items(dataSource: dataSource))
                    expect(collectionView.dataSource).toNot(beNil())
                    connection.newState(state: TestState(someString: "", someFloat: 0,
                                                         numbers: [12, 34],
                                                         sections: [TestSectionModel(header: "section", items: [12,34])],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(dataSource.numberOfSections(in: collectionView)) == 1
                    expect(dataSource.collectionView(collectionView, numberOfItemsInSection: 0)) == 2
                }

                it("can bind table view items") {
                    let tableView = UITableView(frame: CGRect(), style: .plain)
                    let dataSource = RxTableViewSectionedReloadDataSource<TestSectionModel>(
                        configureCell: { _,_,_,item in
                            let cell = UITableViewCell()
                            cell.tag = item
                            return cell
                    }
                    )
                    connection.bind(\ViewControllerProps.sections, to: tableView.rx.items(dataSource: dataSource))
                    expect(tableView.dataSource).toNot(beNil())
                    connection.newState(state: TestState(someString: "", someFloat: 0,
                                                         numbers: [12, 34],
                                                         sections: [TestSectionModel(header: "section", items: [12, 34])],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(dataSource.numberOfSections(in: tableView)) == 1
                    expect(dataSource.tableView(tableView, numberOfRowsInSection: 0)) == 2
                    expect(tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0)).tag) == 12
                    expect(tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: 0)).tag) == 34
                }

                it("can bind table view items with a mapping function") {
                    let tableView = UITableView(frame: CGRect(), style: .plain)
                    let dataSource = RxTableViewSectionedReloadDataSource<TestSectionModel>(
                        configureCell: { _,_,_,item in
                            let cell = UITableViewCell()
                            cell.tag = item
                            return cell
                    }
                    )
                    connection.bind(\ViewControllerProps.sections, to: tableView.rx.items(dataSource: dataSource)) { sections in
                        return sections.map { $0.sorted() }
                    }
                    expect(tableView.dataSource).toNot(beNil())
                    connection.newState(state: TestState(someString: "", someFloat: 0,
                                                         numbers: [12, 34],
                                                         sections: [TestSectionModel(header: "section", items: [34, 12])],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(dataSource.numberOfSections(in: tableView)) == 1
                    expect(dataSource.tableView(tableView, numberOfRowsInSection: 0)) == 2
                    expect(tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0)).tag) == 12
                    expect(tableView.dataSource?.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: 0)).tag) == 34
                }
            }

            describe("binding optional and non-optionals") {
                it("binds non-optional to non-optional") {
                    let barButtonItem = UIBarButtonItem()
                    connection.bind(\ViewControllerProps.str, to: barButtonItem.rx.title)
                    connection.newState(state: TestState(someString: "test string", someFloat: 0.0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(barButtonItem.title) == "test string"
                }

                it("binds non-optional to optional") {
                    let label = UILabel()
                    connection.bind(\ViewControllerProps.str, to: label.rx.text)
                    connection.newState(state: TestState(someString: "test string", someFloat: 0.0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(label.text) == "test string"
                }

                it("binds optional to non-optional") {
                    let barButtonItem = UIBarButtonItem()
                    connection.bind(\ViewControllerProps.optStr, to: barButtonItem.rx.title) { $0! }
                    connection.newState(state: TestState(someString: "test string", someFloat: 0.0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(barButtonItem.title) == "test string"
                }

                it("binds optional to optional") {
                    let label = UILabel()
                    connection.bind(\ViewControllerProps.optStr, to: label.rx.text)
                    connection.newState(state: TestState(someString: "test string", someFloat: 0.0, numbers: [],
                                                         someNonEquatable: NonEquatableStruct(str: "")))
                    expect(label.text) == "test string"
                }
            }
        }
    }
}
