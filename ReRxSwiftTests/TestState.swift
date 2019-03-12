//  Copyright © 2017 Stefan van den Oord. All rights reserved.

import ReSwift

struct TestState: StateType {
    let someString: String
    let someFloat: Float
    let numbers: [Int]
    let maybeInt: Int?
    let sections: [TestSectionModel]
    let someNonEquatable: NonEquatable
    let maybeNonEquatable: NonEquatable?
    let arrayNonEquatable: [NonEquatable]

    init(someString: String,
         someFloat: Float,
         numbers: [Int],
         maybeInt: Int? = nil,
         sections: [TestSectionModel] = [],
         someNonEquatable: NonEquatable,
         maybeNonEquatable: NonEquatable? = nil,
         arrayNonEquatable: [NonEquatable] = []) {
        self.someString = someString
        self.someFloat = someFloat
        self.numbers = numbers
        self.maybeInt = maybeInt
        self.sections = sections
        self.someNonEquatable = someNonEquatable
        self.maybeNonEquatable = maybeNonEquatable
        self.arrayNonEquatable = arrayNonEquatable
    }
}
