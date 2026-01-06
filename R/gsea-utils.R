#' 获取排序后的标准化丰度向量
#'
#' 根据指定的分类等级和目标物种，提取其在所有样本中的丰度，
#' 并进行 Z-score 标准化和降序排列。
#'
#' @param ps A `phyloseq` object.
#' @param target_taxon A character string. The name of the taxon to analyze (e.g., "Bacteroides").
#' @param tax_rank A character string. The taxonomic rank to verify `target_taxon` (e.g., "Genus").
#' @param decreasing Logical. Whether to sort in decreasing order. Default is TRUE.
#'
#' @return A named numeric vector. Names are sample IDs, values are Z-score normalized abundances, sorted decreasingly.
#' @export
get_sorted_abundance_vector <- function(ps, target_taxon, tax_rank, decreasing = TRUE) {

  # 1. 检查输入有效性
  # 检查 tax_rank 是否存在于 tax_table 中
  if (!tax_rank %in% phyloseq::rank_names(ps)) {
    stop(paste("The tax_rank", tax_rank, "is not found in the phyloseq object."))
  }

  # 2. 提取分类表和OTU表
  tax_tab <- as.data.frame(phyloseq::tax_table(ps))
  otu_tab <- phyloseq::otu_table(ps)

  # 确保 OTU 表是 taxa_are_rows 格式，便于后续矩阵运算
  if (!phyloseq::taxa_are_rows(ps)) {
    otu_tab <- phyloseq::t(otu_tab)
  }

  # 3. 查找匹配的 OTU ID (算法优化：避免使用 tax_glom，直接索引)
  # 找到在指定 rank 下名称匹配 target_taxon 的所有 OTU ID
  target_otus <- rownames(tax_tab)[which(tax_tab[[tax_rank]] == target_taxon)]

  if (length(target_otus) == 0) {
    stop(paste("Target taxon", target_taxon, "not found at rank", tax_rank))
  }

  # 4. 计算聚合丰度
  # 如果匹配到多个 OTU（例如多个 OTU 都属于 Bacteroides），则求和
  target_abundance <- otu_tab[target_otus, , drop = FALSE]

  # colSums 计算每个样本的总丰度
  # as.numeric 转换为纯向量，避免保留矩阵属性
  sample_abundance <- as.numeric(colSums(target_abundance))
  names(sample_abundance) <- phyloseq::sample_names(ps)

  # 5. Z-score 标准化 (关键步骤：为了适配 GSEA 的分布假设)
  # 如果不进行 Z-score，丰度全为正值，GSEA 的 running sum 会一直增加，结果不可靠
  abundance_mean <- mean(sample_abundance, na.rm = TRUE)
  abundance_sd <- stats::sd(sample_abundance, na.rm = TRUE)

  # 防止分母为 0 (即所有样本丰度完全一致)
  if (abundance_sd == 0) {
    stop("Standard deviation of abundance is zero. Cannot perform Z-score normalization.")
  }

  z_score_abundance <- (sample_abundance - abundance_mean) / abundance_sd

  # 6. 排序
  # 降序排列，得到名为 "Ranked List"
  sorted_vector <- sort(z_score_abundance, decreasing = decreasing)

  return(sorted_vector)
}

#' 获取样本特征集合列表
#'
#' 将样本元数据（Metadata）中的一列或多列转换为样本 ID 的列表（List of Sets），
#' 用于 GSEA 分析中的 "Pathways"。
#'
#' @param ps A `phyloseq` object.
#' @param cols A character vector. The column name(s) in sample_data to use for grouping.
#'
#' @return A list of character vectors. Each element is a vector of sample IDs belonging to a metadata group.
#' @export
get_sample_feature_sets <- function(ps, cols) {

  # 1. 提取样本元数据
  if (is.null(phyloseq::sample_data(ps, errorIfNULL = FALSE))) {
    stop("The phyloseq object does not contain sample_data.")
  }

  meta_df <- as(phyloseq::sample_data(ps), "data.frame")

  # 检查所有列名是否存在
  missing_cols <- setdiff(cols, colnames(meta_df))
  if (length(missing_cols) > 0) {
    stop(paste("Features not found in sample_data:", paste(missing_cols, collapse = ", ")))
  }

  all_feature_sets <- list()

  for (sample_feat in cols) {
    # 2. 提取目标列并处理缺失值
    # 我们关注样本ID (rownames) 和 目标特征列
    target_col <- meta_df[[sample_feat]]
    sample_ids <- rownames(meta_df)

    # 移除该特征为 NA 的样本
    valid_idx <- !is.na(target_col)
    target_col <- target_col[valid_idx]
    sample_ids <- sample_ids[valid_idx]

    # 3. 构建集合 (List of Sets)
    # 使用 split 函数快速将样本 ID 按特征分组
    # 如果特征是连续变量，建议先在外部离散化，或者在这里强制转为 factor
    # 这里为了通用性，强制转换为字符型分组
    feature_sets <- split(sample_ids, as.factor(target_col))

    if (length(feature_sets) > 0) {
      # 5. 优化命名
      # 给集合名字加上特征前缀，防止混淆 (例如: "Group_Control")
      names(feature_sets) <- paste0(sample_feat, "_", names(feature_sets))

      all_feature_sets <- c(all_feature_sets, feature_sets)
    }
  }

  return(all_feature_sets)
}
