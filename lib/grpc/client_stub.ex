defmodule Bigtable.Service do
  @moduledoc false
  use GRPC.Service, name: "google.bigtable.v2.Bigtable"

  alias Google.Bigtable.V2

  rpc(:ReadRows, V2.ReadRowsRequest, stream(V2.ReadRowsResponse))
  rpc(:MutateRow, V2.MutateRowRequest, stream(V2.MutateRowResponse))
  rpc(:MutateRows, V2.MutateRowsRequest, stream(V2.MutateRowsResponse))
  rpc(:CheckAndMutateRow, V2.CheckAndMutateRowRequest, stream(V2.CheckAndMutateRowResponse))
  rpc(:SampleRowKeys, V2.SampleRowKeysRequest, stream(V2.SampleRowKeysResponse))
end

defmodule Bigtable.Stub do
  @moduledoc false
  use GRPC.Stub, service: Bigtable.Service
end
