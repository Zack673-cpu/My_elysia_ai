from fastapi import APIRouter
from app.models.schemas import SearchRequest, SearchResponse
from app.services.search_service import SearchService

router = APIRouter(prefix="/api/search", tags=["search"])
search_service = SearchService()


@router.post("", response_model=SearchResponse)
async def search(req: SearchRequest):
    """手动执行心理学相关搜索"""
    results = search_service.search(req.query, max_results=req.max_results)
    return SearchResponse(query=req.query, results=results)
