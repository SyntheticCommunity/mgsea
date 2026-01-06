#' 执行微生物群落样本级富集分析 (Sample-Level Enrichment Analysis)
#'
#' 该函数接受 phyloseq 对象，针对特定的目标微生物，分析样本元数据特征是否在
#' 该微生物高丰度或低丰度的样本中富集。
#'
#' @param ps A `phyloseq` object.
#' @param taxon_target A character string. The target taxon name (e.g., "Escherichia").
#' @param taxon_rank A character string. The rank of the target taxon (e.g., "Genus").
#' @param sample_feat A character string. The metadata column name to group samples (e.g., "Group").
#' @param min_size Integer. Minimum size of a feature set. Default is 5.
#' @param max_size Integer. Maximum size of a feature set. Default is 500.
#' @param descreasing Logical. Whether to sort in decreasing order. Default is TRUE.
#'
#' @return A `data.frame` (tbl_df) containing the GSEA results.
#' Columns include: pathway, pval, padj, NES, size, leadingEdge.
#'
#' @importFrom phyloseq tax_table otu_table sample_names rank_names sample_data taxa_are_rows
#' @importFrom fgsea fgsea
#' @importFrom dplyr arrange desc select
#' @importFrom tibble as_tibble
#' @importFrom rlang .data
#'
#' @examples
#' \dontrun{
#' # Suppose there is a ps object.
#' res <- run_microbiome_gsea(
#'     ps = ps_test_data,
#'     taxon_target = "Genus1",
#'     taxon_rank = "Genus",
#'     sample_feat = c("Group", "Source")
#' )
#' print(res)
#' }
#' @export
run_microbiome_gsea <- function(ps, taxon_target, taxon_rank, sample_feat,
                                min_size = 5, max_size = 500,
                                descreasing = TRUE) {

  # 1. 获取排序后的丰度向量 (Stats)
  # 这一步包含了 Z-score 标准化
  message(paste("Calculating ranked abundance for:", taxon_target, "..."))
  sample_ranks <- get_sorted_abundance_vector(ps, taxon_target, taxon_rank, decreasing = descreasing)

  # 2. 获取样本特征集合 (Sets)
  message(paste("Generating sample sets for feature:", sample_feat, "..."))
  sample_sets <- get_sample_feature_sets(ps, sample_feat)

  # 检查是否有足够的集合进行分析
  if (length(sample_sets) == 0) {
    stop("No valid sample sets generated. Check your metadata column or min_size.")
  }

  # 3. 运行 fgsea
  message("Running GSEA analysis...")

  # 设置随机种子以保证结果可重复
  set.seed(123)

  gsea_res <- fgsea::fgsea(
    pathways = sample_sets,
    stats    = sample_ranks,
    minSize  = min_size,
    maxSize  = max_size
  )

  # 4. 结果整理
  # 转换为 tibble 并按 NES (Normalized Enrichment Score) 绝对值或数值排序
  # 这里按 NES 降序排列 (正富集在前，负富集在后)
  gsea_res <- gsea_res %>%
      tibble::as_tibble()

  # 5. 添加属性以便后续绘图
  attr(gsea_res, "sampleSets") <- sample_sets
  attr(gsea_res, "sampleRanks") <- sample_ranks

  return(gsea_res)
}

