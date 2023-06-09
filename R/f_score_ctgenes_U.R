#' Calculate cell type score
#'
#' @param sce A SingleCellExperiment object containing the expression
#' profiles of the single cell analysis.
#' @param gset Marker gene list for all cell types.
#' @param min_genes Minimum number of genes.
#' @param gene_symbol Variable name in the row data of the SingleCellExperiment object containing the gene names.
#' @param count_data Assay name in the SingleCellExperiment object containing the count data.
#' @param verbose Level of verbosity. Zero means silent, one makes a verbose output.
#' @return Matrix containing the cell type scores. The rows represent the cell types, whereas the columns represent the samples.
#'
#' @export
#'
#' @examples
#' \donttest{
#' data("test_sce_data")
#' gset <- list(cell_type1 = c("CD79A", "TCL1A", "VPREB3"),
#' cell_type2 = c("FCER1A", "CLEC10A", "ENHO"))
#' f_score_ctgenes_U(test_sce_data[,1:3], gset, count_data = "normcounts",
#' gene_symbol = "SYMBOL", min_genes = 3, verbose = 0)
#' }

f_score_ctgenes_U <- function(sce, gset, count_data = "normcounts", gene_symbol = "SYMBOL", min_genes = 5,verbose = 0) {
  if(verbose ==1){
    cat("\nCalculate scores for cell type classification.")
  }
  # gset = cell.type[these.ct]
  # sce = these.cells
  # min_genes = 5
  # select count table with all.ct.genes
  all.genes <- unique(as.character(unlist(gset)))
  if(verbose == 1){
    cat("\n\nNumber of genes on cell type specific lists:", length(all.genes))
  }
  # count matrix including all cells and only the cell type specific genes
  mat <- SummarizedExperiment::assay(sce, count_data)[SingleCellExperiment::rowData(sce)[,gene_symbol] %in% all.genes, , drop = F]
  if(verbose ==1){
    cat("\n\nNumber of genes included in matrix:", dim(mat)[1])
  }
  # keep genes only if they have counts in at least one cell
  keep <- rowSums(mat)
  mat <- mat[keep > 0, , drop = F]
  if(verbose ==1){
    cat("\n\nNumber of genes with with a sum of counts > 0:", dim(mat)[1], "\n\n\n")
  }
  colnames(mat) <- sce$barcodes
  # get row index of dd for each gene in a list of celltypes
  idxs <- limma::ids2indices(gene.sets = gset, rownames(mat), remove.empty = F)
  # generate gene x celltype matrix
  # all values are 0
  ds <- matrix(0, nrow = nrow(mat), ncol = length(idxs))
  rownames(ds) <- rownames(mat)
  colnames(ds) <- names(idxs)
  # fill matrix with 1 where a gene is specific for a cell type
  for (cell_type in seq(length(idxs))) {
    ds[idxs[[cell_type]], cell_type] <- 1
  }
  # perform wilcox test using gene x sample and gene x celltype matrices.
  # wilcox.test(mat[ds[,1]==1,1],mat[ds[,1]==0,1])$p.value
  m.cts <- apply(mat, 2, function(x) {
    # on each column of mat (each cell)
    # perform wilcox test with each list of cell type genes against all other cell type genes
    apply(ds, 2, function(y) f_my_wilcox_test(x[y == 1], x[y == 0], min_genes))
  })
  m.cts[is.na(m.cts)] <- 1
  return(m.cts)
}
