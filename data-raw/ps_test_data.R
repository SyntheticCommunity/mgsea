# ============================================================
# 脚本路径: data-raw/generate_sysdata.R
# 目的: 生成用于测试的 phyloseq 对象并保存到 R/sysdata.rda
# ============================================================

library(phyloseq)

# 1. 设置随机种子以保证结果可重复
set.seed(2023)

# 2. 定义维度
n_samples <- 50
n_taxa <- 9

# 3. 模拟 OTU 表 (Taxa x Samples)
# 随机生成 0-100 的计数值
otu_mat <- matrix(sample(0:99, n_samples * n_taxa, replace = TRUE), nrow = n_taxa)
rownames(otu_mat) <- paste0("OTU", sprintf("%01s", 1:n_taxa))
colnames(otu_mat) <- paste0("Sample", sprintf("%02s", 1:n_samples))

# 4. 模拟分类表 (Taxonomy Table)
# 这里简单地将 OTU 映射到 Genus，每个 OTU 对应一个唯一的 Genus
tax_mat <- matrix(rep(paste0("Genus", 1:n_taxa), each = 1), ncol = 1)
rownames(tax_mat) <- rownames(otu_mat)
colnames(tax_mat) <- "Genus"

# 5. 模拟元数据 (Sample Data)
# 制造一种情况：Sample1-25 是 "Ctrl"，Sample26-50 是 "Treat"
meta_df <- data.frame(
  Group = sample(c("Ctrl", "Treat"), 50, replace = TRUE),
  Source = sample(c("Fecal", "Oral"), 50, replace = TRUE),
  row.names = colnames(otu_mat)
)

# 6. 注入信号 (关键步骤)
# 让 Genus1 (对应 OTU1) 在 "Treat" 组 (后25个样本) 丰度显著更高
# 这样在测试 GSEA 时，我们预期 "Group_Treat" 会显著富集
grp_treat = meta_df$Group == "Treat"
otu_mat[1, grp_treat] <- otu_mat[1, grp_treat] + round(runif(sum(grp_treat), 30, 50))

# 7. 构建 phyloseq 对象
ps_test_data <- phyloseq(
  otu_table(otu_mat, taxa_are_rows = TRUE),
  tax_table(tax_mat),
  sample_data(meta_df)
)

# 8. 保存为 sysdata.rda
# use_data 是 usethis 包的函数，它会自动将数据保存到 R/sysdata.rda
# internal = TRUE 表示这是一个内部数据
usethis::use_data(ps_test_data, internal = TRUE, overwrite = TRUE)
