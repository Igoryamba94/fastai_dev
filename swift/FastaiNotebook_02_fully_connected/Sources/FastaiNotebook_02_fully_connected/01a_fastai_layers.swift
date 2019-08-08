/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: 01a_fastai_layers.ipynb

*/



import Path
import TensorFlow

public extension Tensor where Scalar: TensorFlowFloatingPoint {
    init(kaimingNormal shape: TensorShape, negativeSlope: Double = 1.0) {
        // Assumes Leaky ReLU nonlinearity
        let gain = Scalar.init(TensorFlow.sqrt(2.0 / (1.0 + TensorFlow.pow(negativeSlope, 2))))
        let spatialDimCount = shape.count - 2
        let receptiveField = shape[0..<spatialDimCount].contiguousSize
        let fanIn = shape[spatialDimCount] * receptiveField
        self.init(randomNormal: shape)
        self *= Tensor<Scalar>(gain/TensorFlow.sqrt(Scalar(fanIn)))
    }
}

public extension Tensor where Scalar: TensorFlowFloatingPoint {
    func std() -> Tensor<Scalar> { return standardDeviation() }
    func std(alongAxes a: [Int]) -> Tensor<Scalar> { return standardDeviation(alongAxes: a) }
    func std(alongAxes a: Tensor<Int32>) -> Tensor<Scalar> { return standardDeviation(alongAxes: a) }
    func std(alongAxes a: Int...) -> Tensor<Scalar> { return standardDeviation(alongAxes: a) }
    func std(squeezingAxes a: [Int]) -> Tensor<Scalar> { return standardDeviation(squeezingAxes: a) }
    func std(squeezingAxes a: Tensor<Int32>) -> Tensor<Scalar> { return standardDeviation(squeezingAxes: a) }
    func std(squeezingAxes a: Int...) -> Tensor<Scalar> { return standardDeviation(squeezingAxes: a) }
}


// FALayer is a layer that supports callbacks through its LayerDelegate.
public protocol FALayer: Layer {
    var delegates: [(Output) -> ()] { get set }
    
    // FALayer's will implement this instead of `func call`.
    @differentiable
    func forward(_ input: Input) -> Output
    
    associatedtype Input
    associatedtype Output
}

public extension FALayer {
    @differentiable(vjp: callGrad)
    @differentiable(wrt: (self))
    func callAsFunction(_ input: Input) -> Output {
        let activation = forward(input)
        for d in delegates { d(activation) }
        return activation
    }
       
    func callGrad(_ input: Input) ->
        (Output, (Self.Output.TangentVector) -> (Self.TangentVector, Self.Input.TangentVector)) {
        return Swift.valueWithPullback(at: self, input) { (m, i) in m.forward(i) }
    }
    
    mutating func addDelegate(_ d: @escaping (Output) -> ()) { delegates.append(d) }
}


@frozen
public struct FADense<Scalar: TensorFlowFloatingPoint>: FALayer {
    // Note: remove the explicit typealiases after TF-603 is resolved.
    public typealias Input = Tensor<Scalar>
    public typealias Output = Tensor<Scalar>
    public var weight: Tensor<Scalar>
    public var bias: Tensor<Scalar>
    public typealias Activation = @differentiable (Tensor<Scalar>) -> Tensor<Scalar>
    @noDerivative public var delegates: [(Output) -> ()] = []
    @noDerivative public let activation: Activation

    public init(
        weight: Tensor<Scalar>,
        bias: Tensor<Scalar>,
        activation: @escaping Activation
    ) {
        self.weight = weight
        self.bias = bias
        self.activation = activation
    }

    @differentiable
    public func forward(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        return activation(input • weight + bias)
    }
}

public extension FADense {
    init(_ nIn: Int, _ nOut: Int, activation: @escaping Activation = identity) {
        self.init(weight: Tensor(kaimingNormal: [nIn, nOut], negativeSlope: 1.0),
                  bias: Tensor(zeros: [nOut]),
                  activation: activation)
    }
}


@frozen
public struct FANoBiasConv2D<Scalar: TensorFlowFloatingPoint>: FALayer {
    // TF-603 workaround.
    public typealias Input = Tensor<Scalar>
    public typealias Output = Tensor<Scalar>
    
    public var filter: Tensor<Scalar>
    public typealias Activation = @differentiable (Tensor<Scalar>) -> Tensor<Scalar>
    @noDerivative public let activation: Activation
    @noDerivative public let strides: (Int, Int)
    @noDerivative public let padding: Padding
    @noDerivative public var delegates: [(Output) -> ()] = []

    public init(
        filter: Tensor<Scalar>,
        activation: @escaping Activation,
        strides: (Int, Int),
        padding: Padding
    ) {
        self.filter = filter
        self.activation = activation
        self.strides = strides
        self.padding = padding
    }

    @differentiable
    public func forward(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        return activation(conv2D(input, filter: filter,
                                        strides: (1, strides.0, strides.1, 1),
                                        padding: padding))
    }
}

public extension FANoBiasConv2D {
    init(
        filterShape: (Int, Int, Int, Int),
        strides: (Int, Int) = (1, 1),
        padding: Padding = .same,
        activation: @escaping Activation = identity
    ) {
        let filterTensorShape = TensorShape([
            filterShape.0, filterShape.1,
            filterShape.2, filterShape.3])
        self.init(
            filter: Tensor(kaimingNormal: filterTensorShape, negativeSlope: 1.0),
            activation: activation,
            strides: strides,
            padding: padding)
    }
}

public extension FANoBiasConv2D {
    init(_ cIn: Int, _ cOut: Int, ks: Int, stride: Int = 1, padding: Padding = .same,
         activation: @escaping Activation = identity){
        self.init(filterShape: (ks, ks, cIn, cOut),
                  strides: (stride, stride),
                  padding: padding,
                  activation: activation)
    }
}


@frozen
public struct FAConv2D<Scalar: TensorFlowFloatingPoint>: FALayer {
    // Note: remove the explicit typealiases after TF-603 is resolved.
    public typealias Input = Tensor<Scalar>
    public typealias Output = Tensor<Scalar>
    
    public var filter: Tensor<Scalar>
    public var bias: Tensor<Scalar>
    public typealias Activation = @differentiable (Tensor<Scalar>) -> Tensor<Scalar>
    @noDerivative public let activation: Activation
    @noDerivative public let strides: (Int, Int)
    @noDerivative public let padding: Padding
    @noDerivative public var delegates: [(Output) -> ()] = []

    public init(
        filter: Tensor<Scalar>,
        bias: Tensor<Scalar>,
        activation: @escaping Activation,
        strides: (Int, Int),
        padding: Padding
    ) {
        self.filter = filter
        self.bias = bias
        self.activation = activation
        self.strides = strides
        self.padding = padding
    }

    @differentiable
    public func forward(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        return activation(conv2D(input, filter: filter,
                                        strides: (1, strides.0, strides.1, 1),
                                        padding: padding) + bias)
    }
}

public extension FAConv2D {
    init(
        filterShape: (Int, Int, Int, Int),
        strides: (Int, Int) = (1, 1),
        padding: Padding = .same,
        activation: @escaping Activation = identity
    ) {
        let filterTensorShape = TensorShape([
            filterShape.0, filterShape.1,
            filterShape.2, filterShape.3])
        self.init(
            filter: Tensor(kaimingNormal: filterTensorShape, negativeSlope: 1.0),
            bias: Tensor(zeros: TensorShape([filterShape.3])),
            activation: activation,
            strides: strides,
            padding: padding)
    }
}

public extension FAConv2D {
    init(_ cIn: Int, _ cOut: Int, ks: Int, stride: Int = 1, padding: Padding = .same,
         activation: @escaping Activation = identity){
        self.init(filterShape: (ks, ks, cIn, cOut),
                  strides: (stride, stride),
                  padding: padding,
                  activation: activation)
    }
}


@frozen
public struct FAAvgPool2D<Scalar: TensorFlowFloatingPoint>: FALayer,ParameterlessLayer {
    // TF-603 workaround.
    public typealias Input = Tensor<Scalar>
    public typealias Output = Tensor<Scalar>
    
    @noDerivative let poolSize: (Int, Int, Int, Int)
    @noDerivative let strides: (Int, Int, Int, Int)
    @noDerivative let padding: Padding
    @noDerivative public var delegates: [(Output) -> ()] = []

    public init(
        poolSize: (Int, Int, Int, Int),
        strides: (Int, Int, Int, Int),
        padding: Padding
    ) {
        self.poolSize = poolSize
        self.strides = strides
        self.padding = padding
    }

    public init(poolSize: (Int, Int), strides: (Int, Int), padding: Padding = .valid) {
        self.poolSize = (1, poolSize.0, poolSize.1, 1)
        self.strides = (1, strides.0, strides.1, 1)
        self.padding = padding
    }
    
    public init(_ sz: Int, padding: Padding = .valid) {
        poolSize = (1, sz, sz, 1)
        strides = (1, sz, sz, 1)
        self.padding = padding
    }

    @differentiable
    public func forward(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        return avgPool2D(input, filterSize: poolSize, strides: strides, padding: padding)
    }
}


@frozen
public struct FAGlobalAvgPool2D<Scalar: TensorFlowFloatingPoint>: FALayer,ParameterlessLayer {
    // TF-603 workaround.
    public typealias Input = Tensor<Scalar>
    public typealias Output = Tensor<Scalar>
    @noDerivative public var delegates: [(Output) -> ()] = []
    
    public init() {}

    @differentiable
    public func forward(_ input: Tensor<Scalar>) -> Tensor<Scalar> {
        return input.mean(squeezingAxes: [1,2])
    }
}

extension Array: Layer&Module where Element: Layer, Element.Input == Element.Output {
    // Note: remove the explicit typealiases after TF-603 is resolved.
    public typealias Input = Element.Input
    public typealias Output = Element.Output

    @differentiable
    public func callAsFunction(_ input: Input) -> Output {
          return self.differentiableReduce(input) { $1($0) }
    }
}

extension KeyPathIterable {
    public var keyPaths: [WritableKeyPath<Self, Tensor<Float>>] {
        return recursivelyAllWritableKeyPaths(to: Tensor<Float>.self)
    }
}

//extension Layer {
//    public var variables: AllDifferentiableVariables {
//        get { return allDifferentiableVariables }
//        set { allDifferentiableVariables = newValue }
//    }
//}

public func ** (lhs: Int, rhs: Int) -> Int {
    return Int(pow(Double(lhs), Double(rhs)))
}

public func ** (lhs: Double, rhs: Double) -> Double {
    return pow(lhs, rhs)
}

public func **<T : BinaryFloatingPoint>(_ x: T, _ y: T) -> T {
    return T(pow(Double(x), Double(y)))
}

public func **<T>(_ x: Tensor<T>, _ y: Tensor<T>) -> Tensor<T>
  where T : TensorFlowFloatingPoint { return pow(x, y)}

public func **<T>(_ x: T, _ y: Tensor<T>) -> Tensor<T>
  where T : TensorFlowFloatingPoint { return pow(x, y)}

public func **<T>(_ x: Tensor<T>, _ y: T) -> Tensor<T>
  where T : TensorFlowFloatingPoint { return pow(x, y)}

public extension Differentiable {
    @differentiable
    func compose<L1: Layer, L2: Layer>(_ l1: L1, _ l2: L2) -> L2.Output
        where L1.Input == Self, L1.Output == L2.Input {
        return sequenced(through: l1, l2)
    }
    
    @differentiable
    func compose<L1: Layer, L2: Layer, L3: Layer>(_ l1: L1, _ l2: L2, _ l3: L3) -> L3.Output
        where L1.Input == Self, L1.Output == L2.Input, L2.Output == L3.Input {
        return sequenced(through: l1, l2, l3)
    }
    
    @differentiable
    func compose<L1: Layer, L2: Layer, L3: Layer, L4: Layer>(
        _ l1: L1, _ l2: L2, _ l3: L3, _ l4: L4
    ) -> L4.Output
        where L1.Input == Self, L1.Output == L2.Input, L2.Output == L3.Input,
              L3.Output == L4.Input {
        return sequenced(through: l1, l2, l3, l4)
    }
    
    @differentiable
    func compose<L1: Layer, L2: Layer, L3: Layer, L4: Layer, L5: Layer>(
        _ l1: L1, _ l2: L2, _ l3: L3, _ l4: L4, _ l5: L5
    ) -> L5.Output
        where L1.Input == Self, L1.Output == L2.Input, L2.Output == L3.Input, L3.Output == L4.Input,
              L4.Output == L5.Input {
        return sequenced(through: l1, l2, l3, l4, l5)
    }
    
    @differentiable
    func compose<L1: Layer, L2: Layer, L3: Layer, L4: Layer, L5: Layer, L6: Layer>(
        _ l1: L1, _ l2: L2, _ l3: L3, _ l4: L4, _ l5: L5, _ l6: L6
    ) -> L6.Output
        where L1.Input == Self, L1.Output == L2.Input, L2.Output == L3.Input, L3.Output == L4.Input,
              L4.Output == L5.Input, L5.Output == L6.Input {
        return sequenced(through: l1, l2, l3, l4, l5, l6)
    }
}
