using GeoArtifacts
using GeoInterface
#using GeoTables
using CairoMakie
using DataFrames
using CSV
using ColorSchemes
#using ColorTypes
using Colors
#using Meshes
using Statistics  # Importando para usar a função mean

set_theme!(theme_dark())

# Função para determinar a cor do texto baseado no brilho da cor de fundo
function text_color(c)
    rgb = convert(RGB, c)
    luminance = 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
    return luminance > 0.6 ? RGB(0,0,0) : RGB(1,1,1)
end

# Mapeamento de nomes completos para siglas
const SIGLAS_UF = Dict(
    "Acre" => "AC",
    "Alagoas" => "AL",
    "Amapá" => "AP",
    "Amazonas" => "AM",
    "Bahia" => "BA",
    "Ceará" => "CE",
    "Distrito Federal" => "DF",
    "Espírito Santo" => "ES",
    "Goiás" => "GO",
    "Maranhão" => "MA",
    "Mato Grosso" => "MT",
    "Mato Grosso do Sul" => "MS",
    "Minas Gerais" => "MG",
    "Pará" => "PA",
    "Paraíba" => "PB",
    "Paraná" => "PR",
    "Pernambuco" => "PE",
    "Piauí" => "PI",
    "Rio de Janeiro" => "RJ",
    "Rio Grande do Norte" => "RN",
    "Rio Grande do Sul" => "RS",
    "Rondônia" => "RO",
    "Roraima" => "RR",
    "Santa Catarina" => "SC",
    "São Paulo" => "SP",
    "Sergipe" => "SE",
    "Tocantins" => "TO"
)

# Função alternativa para encontrar um ponto central aproximado
function approximate_center(geom)
    coords = GeoInterface.coordinates(geom)
    all_points = Vector{Point2f}()
    
    for poly in coords
        exterior = poly[1]
        points = Point2f.(first.(exterior), last.(exterior))
        append!(all_points, points)
    end
    
    # Calcular a média das coordenadas
    mean_x = mean([p[1] for p in all_points])
    mean_y = mean([p[2] for p in all_points])
    
    return Point2f(mean_x, mean_y)
end

# 1. Carregar os dados
df = CSV.read("tabela5938_uf.csv", DataFrame)

# Filtrar para o ano de 2020
df_2020 = filter(:ano => ==(2020), df)

# Dicionário PIB por estado
pib_dict = Dict{String, Float64}()
for row in eachrow(df_2020)
    pib_dict[row.uf] = row.valor * 1_000  # Convertendo de mil R$ para R$
end

# 2. Carregar geometria dos estados
estados = GeoBR.state()

# Obter valores do PIB
pib_values = [get(pib_dict, estados.name_state[i], missing) for i in 1:length(estados.name_state)]

# Filtrar estados com valor disponível
has_value = .!ismissing.(pib_values)
geoms = [estados.geometry[i] for i in eachindex(estados.geometry) if has_value[i]]
pib_values = pib_values[has_value]
nomes_estados = estados.name_state[has_value]
siglas_uf = [SIGLAS_UF[name] for name in nomes_estados]

# 3. Transformação logarítmica
log_pib_values = log10.(pib_values)
pib_min, pib_max = extrema(log_pib_values)

# 4. Configuração de cores
colors = [get(ColorSchemes.viridis, (x - pib_min) / (pib_max - pib_min)) for x in log_pib_values]

# 5. Configuração do mapa
fig = Figure(size = (1000, 900))

# Limites geográficos do Brasil
lon_min, lon_max = -75.0, -30.0
lat_min, lat_max = -35.0, 5.0

ax = Axis(fig[1, 1],
    title = "PIB por Estado (2020) - Escala Logarítmica",
    xlabel = "Longitude (Oeste)",
    ylabel = "Latitude",
    aspect = DataAspect(),
    limits = (lon_min, lon_max, lat_min, lat_max)
)

# Configuração das grades
ax.xgridvisible = true
ax.ygridvisible = true
ax.xgridcolor = (:gray, 0.2)
ax.ygridcolor = (:gray, 0.2)
ax.xgridstyle = :dash
ax.ygridstyle = :dash

# Configuração dos ticks
ax.xticks = -75:10:-30
ax.yticks = -35:10:5

# 6. Plotagem dos estados e siglas
for (i, geom) in enumerate(geoms)
    coords = GeoInterface.coordinates(geom)
    for poly in coords
        exterior = poly[1]
        pontos = Point2f.(first.(exterior), last.(exterior))
        poly!(ax, pontos, color = colors[i], strokecolor = (:black, 0.5), strokewidth = 0.5)
    end
    
    # Calcular posição aproximada para a sigla
    center = approximate_center(geom)
    
    # Determinar cor do texto baseado na cor do estado
    txt_color = text_color(colors[i])
    
    # Adicionar texto da sigla
    text!(ax, siglas_uf[i], 
        position = center,
        color = txt_color,
        align = (:center, :center),
        fontsize = 12,
        font = "Arial Bold")
end

# 7. Barra de cores
Colorbar(fig[1, 2],
    limits = (pib_min, pib_max),
    colormap = :viridis,
    label = raw"log₁₀(PIB em R$)",
    width = 20,
    ticks = LinearTicks(5)
)

# 8. Exibição dos top estados
df_top = sort(df_2020, :valor, rev=true)
println("\nTop 10 maiores PIBs estaduais em 2020:")

for (i, row) in enumerate(eachrow(df_top[1:10, :]))
    valor_real = row.valor * 1_000  # Convertendo de mil R$ para R$
    if valor_real >= 1e12
        println("$i. $(row.uf): R\$ $(round(valor_real / 1e12, digits=2)) trilhões")
    else
        println("$i. $(row.uf): R\$ $(round(valor_real / 1e9, digits=2)) bilhões")
    end
end

fig
