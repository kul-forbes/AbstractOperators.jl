export BroadCast

"""
`BroadCast(A::AbstractOperator, dim_out...)`


BroadCast the codomain dimensions of an `AbstractOperator`.

```julia
julia> A = Eye(2)
I  ℝ^2 -> ℝ^2

julia> B = BroadCast(A,(2,3))
.I  ℝ^2 -> ℝ^(2, 3)

julia> B*[1.;2.]
2×3 Array{Float64,2}:
 1.0  1.0  1.0
 2.0  2.0  2.0

```

"""
struct BroadCast{N, 
		 L <: AbstractOperator, 
		 T <: AbstractArray, 
		 D <: AbstractArray,
		 M,
		 C <: NTuple{M,Colon},
		 I <: CartesianRange
		 } <: AbstractOperator
	A::L
	dim_out::NTuple{N,Int}
	bufC::T
	bufD::D
	cols::C
	idxs::I

	function BroadCast(A::L,dim_out::NTuple{N,Int},bufC::T, bufD::D) where {N, 
								      L<:AbstractOperator, 
								      T<:AbstractArray,
								      D<:AbstractArray
								      }
		Base.Broadcast.check_broadcast_shape(dim_out,size(A,1))
		if size(A,1) != (1,)
			M = length(size(A,1)) 
			cols = ([Colon() for i = 1:M]...)
			idxs = CartesianRange((dim_out[M+1:end]...))
			new{N,L,T,D,M,typeof(cols),typeof(idxs)}(A,dim_out,bufC,bufD,cols,idxs)
		else #singleton case
			M = 0
			idxs = CartesianRange((1,))
			new{N,L,T,D,M,NTuple{0,Colon},typeof(idxs)}(A,dim_out,bufC,bufD,(),idxs)
		end
		
	end
end

# Constructors

BroadCast(A::L, dim_out::NTuple{N,Int}) where {N,L<:AbstractOperator} =
BroadCast(A, dim_out, zeros(codomainType(A),size(A,1)), zeros(domainType(A),size(A,2)) )

# Mappings

function A_mul_B!(y::C, R::BroadCast{N,L}, b::D) where {N,L,C,D}
	A_mul_B!(R.bufC, R.A, b)
	y .= R.bufC
end

function Ac_mul_B!(y::C, R::BroadCast{N,L}, b::D) where {N,L,C,D}
	fill!(y, 0.)
	for i in R.idxs
		@views Ac_mul_B!(R.bufD, R.A, b[R.cols...,i.I...])
		y .+= R.bufD
	end
	return y
end

#singleton
function Ac_mul_B!(y::CC, R::BroadCast{N,L,T,D,0}, b::DD) where {N,L,T,D,CC,DD}
	fill!(y, 0.)
	bii = zeros(eltype(b),1)
	for bi in b
		bii[1] = bi
		Ac_mul_B!(R.bufD, R.A, bii)
		y .+= R.bufD
	end
	return y
end

#singleton Eye
function Ac_mul_B!(y::CC, R::BroadCast{N,L,T,D,0}, b::DD) where {N,L<:Eye,T,D,CC,DD}
	sum!(y,b)
end

# Properties

size(R::BroadCast) = (R.dim_out, size(R.A,2))

  domainType(  R::BroadCast) =   domainType(R.A)
codomainType(  R::BroadCast) = codomainType(R.A)

is_linear(      R::BroadCast) = is_linear(R.A)
is_null(        R::BroadCast) = is_null(R.A)

fun_name(R::BroadCast) = "."fun_name(R.A)